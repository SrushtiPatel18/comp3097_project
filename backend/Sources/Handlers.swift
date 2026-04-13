import Glibc

// MARK: - Route registration

func registerRoutes(router: Router, storage: Storage, server: HTTPServer, startTime: Int) {

    // MARK: Health

    router.get("/health") { _, _ in
        let stats   = server.getStats()
        let uptime  = currentTimestamp() - startTime
        let body =
            "{\"status\":\"ok\"" +
            ",\"version\":\"\(APP_VERSION)\"" +
            ",\"uptime\":\(uptime)" +
            ",\"requests\":\(stats.requests)" +
            ",\"activeConnections\":\(stats.activeConns)" +
            "}"
        return .ok(body)
    }

    // MARK: Transactions — list (with pagination, search, filter)

    router.get("/transactions") { req, _ in
        let p = req.queryParams

        // Filters forwarded to Storage
        let txs = storage.allTransactions(
            categoryId: p["categoryId"],
            type:       p["type"],
            search:     p["search"],
            from:       p["from"],
            to:         p["to"]
        )

        let total = txs.count

        // Pagination
        let page  = max(1, Int(p["page"]  ?? "") ?? 1)
        let limit = min(max(1, Int(p["limit"] ?? "") ?? 50), 200)
        let start = (page - 1) * limit
        let end   = min(start + limit, total)
        let slice = start < total ? Array(txs[start..<end]) : []
        let pages = total == 0 ? 1 : (total + limit - 1) / limit

        let items = JSONValue.array(slice.map { $0.toJSON() }).json
        let meta  =
            "{\"total\":\(total)" +
            ",\"page\":\(page)" +
            ",\"limit\":\(limit)" +
            ",\"pages\":\(pages)" +
            "}"
        return .ok("{\"data\":\(items),\"meta\":\(meta)}")
    }

    // MARK: Transactions — single

    router.get("/transactions/:id") { _, params in
        guard let id = params["id"] else { throw AppError.badRequest("Missing id") }
        guard let tx = storage.findTransaction(id: id) else {
            throw AppError.notFound("Transaction '\(id)' not found")
        }
        return .ok(tx.toJSON().json)
    }

    // MARK: Transactions — create

    router.post("/transactions") { req, _ in
        guard let json = parseJSON(req.body) else {
            throw AppError.badRequest("Request body must be valid JSON")
        }
        guard let title   = json["title"]?.asString,
              let amount  = json["amount"]?.asDouble,
              let typeStr = json["type"]?.asString,
              let txType  = TransactionType(rawValue: typeStr),
              let catId   = json["categoryId"]?.asString,
              let date    = json["date"]?.asString
        else {
            throw AppError.badRequest("Required fields: title, amount, type, categoryId, date")
        }
        let note = json["note"]?.asString ?? ""
        let id   = json["id"]?.asString   ?? generateID()
        let now  = currentTimestamp()
        let tx   = Transaction(id: id, title: title, amount: amount, type: txType,
                               categoryId: catId, date: date, note: note,
                               createdAt: now, updatedAt: now)
        try tx.validate()
        try storage.addTransaction(tx)
        logger.info("Created transaction \(id): \(title) (\(amount))")
        return .created(tx.toJSON().json)
    }

    // MARK: Transactions — update

    router.put("/transactions/:id") { req, params in
        guard let id = params["id"] else { throw AppError.badRequest("Missing id") }
        guard var tx = storage.findTransaction(id: id) else {
            throw AppError.notFound("Transaction '\(id)' not found")
        }
        guard let json = parseJSON(req.body) else {
            throw AppError.badRequest("Request body must be valid JSON")
        }
        tx.applyPatch(json)
        try tx.validate()
        try storage.updateTransaction(tx)
        return .ok(tx.toJSON().json)
    }

    // MARK: Transactions — delete

    router.delete("/transactions/:id") { _, params in
        guard let id = params["id"] else { throw AppError.badRequest("Missing id") }
        try storage.deleteTransaction(id: id)
        logger.info("Deleted transaction \(id)")
        return .noContent()
    }

    // MARK: Summary / Analytics

    router.get("/summary") { req, _ in
        let p = req.queryParams
        let s = storage.summary(
            from:       p["from"],
            to:         p["to"],
            categoryId: p["categoryId"]
        )
        let body =
            "{\"income\":\(jsonDouble(s.totalIncome))" +
            ",\"expense\":\(jsonDouble(s.totalExpense))" +
            ",\"balance\":\(jsonDouble(s.balance))" +
            ",\"count\":\(s.count)" +
            "}"
        return .ok(body)
    }

    // MARK: Categories — list

    router.get("/categories") { _, _ in
        .ok(JSONValue.array(storage.allCategories().map { $0.toJSON() }).json)
    }

    // MARK: Categories — single

    router.get("/categories/:id") { _, params in
        guard let id = params["id"] else { throw AppError.badRequest("Missing id") }
        guard let cat = storage.findCategory(id: id) else {
            throw AppError.notFound("Category '\(id)' not found")
        }
        return .ok(cat.toJSON().json)
    }

    // MARK: Categories — create

    router.post("/categories") { req, _ in
        guard let json = parseJSON(req.body) else {
            throw AppError.badRequest("Request body must be valid JSON")
        }
        guard let name = json["name"]?.asString else {
            throw AppError.badRequest("Required field: name")
        }
        // Uniqueness check
        if storage.categoryNameExists(name) {
            throw AppError.conflict("A category named '\(name)' already exists")
        }
        let id    = json["id"]?.asString    ?? generateID()
        let icon  = json["icon"]?.asString  ?? "circle"
        let color = json["color"]?.asString ?? "#6366f1"
        let type  = json["type"]?.asString  ?? "both"
        let now   = currentTimestamp()
        let cat   = Category(id: id, name: name, icon: icon, color: color,
                             type: type, isDefault: false, createdAt: now, updatedAt: now)
        try cat.validate()
        try storage.addCategory(cat)
        logger.info("Created category \(id): \(name)")
        return .created(cat.toJSON().json)
    }

    // MARK: Categories — update

    router.put("/categories/:id") { req, params in
        guard let id = params["id"] else { throw AppError.badRequest("Missing id") }
        guard var cat = storage.findCategory(id: id) else {
            throw AppError.notFound("Category '\(id)' not found")
        }
        guard let json = parseJSON(req.body) else {
            throw AppError.badRequest("Request body must be valid JSON")
        }
        // Name uniqueness check (excluding self)
        if let newName = json["name"]?.asString, !newName.isEmpty,
           storage.categoryNameExists(newName, excludingId: id) {
            throw AppError.conflict("A category named '\(newName)' already exists")
        }
        cat.applyPatch(json)
        try cat.validate()
        try storage.updateCategory(cat)
        return .ok(cat.toJSON().json)
    }

    // MARK: Categories — delete

    router.delete("/categories/:id") { _, params in
        guard let id = params["id"] else { throw AppError.badRequest("Missing id") }
        // findCategory + isDefault check delegated to Storage.deleteCategory
        try storage.deleteCategory(id: id)
        logger.info("Deleted category \(id)")
        return .noContent()
    }

    // MARK: Settings — get

    router.get("/settings") { _, _ in
        .ok(storage.getSettings().toJSON().json)
    }

    // MARK: Settings — update (PUT or PATCH both do partial update)

    router.put("/settings")   { req, _ in try applySettingsPatch(req: req, storage: storage) }
    router.patch("/settings") { req, _ in try applySettingsPatch(req: req, storage: storage) }
}

// MARK: - Private helpers

private func applySettingsPatch(req: HTTPRequest, storage: Storage) throws -> HTTPResponse {
    guard let json = parseJSON(req.body) else {
        throw AppError.badRequest("Request body must be valid JSON")
    }
    var s = storage.getSettings()
    s.applyPatch(json)
    try s.validate()
    try storage.updateSettings(s)
    return .ok(s.toJSON().json)
}

/// Format a Double for JSON output (no unnecessary trailing zeros).
private func jsonDouble(_ d: Double) -> String {
    if d.truncatingRemainder(dividingBy: 1) == 0 && d.magnitude < 1e15 {
        return "\(Int(d)).0"
    }
    return "\(d)"
}
