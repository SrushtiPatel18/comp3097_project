import Glibc

// MARK: - Register all routes

func registerRoutes(router: Router, storage: Storage) {

    // MARK: Health

    router.get("/health") { _, _ in
        let body = "{\"status\":\"ok\",\"version\":\"1.0.0\"}"
        return .ok(body)
    }

    // MARK: Transactions

    router.get("/transactions") { req, _ in
        let categoryId = req.queryParams["categoryId"]
        let txs = storage.allTransactions(categoryId: categoryId)
        let body = JSONValue.array(txs.map { $0.toJSON() }).json
        return .ok(body)
    }

    router.get("/transactions/:id") { _, params in
        guard let id = params["id"] else { throw AppError.badRequest("Missing id") }
        guard let tx = storage.findTransaction(id: id) else {
            throw AppError.notFound("Transaction \(id) not found")
        }
        return .ok(tx.toJSON().json)
    }

    router.post("/transactions") { req, _ in
        guard let json = parseJSON(req.body) else {
            throw AppError.badRequest("Invalid JSON body")
        }
        guard let title    = json["title"]?.asString,
              let amount   = json["amount"]?.asDouble,
              let typeStr  = json["type"]?.asString,
              let txType   = TransactionType(rawValue: typeStr),
              let catId    = json["categoryId"]?.asString,
              let date     = json["date"]?.asString
        else {
            throw AppError.badRequest("Required fields: title, amount, type, categoryId, date")
        }
        let note = json["note"]?.asString ?? ""
        let id   = json["id"]?.asString ?? generateID()
        let now  = currentTimestamp()
        let tx   = Transaction(id: id, title: title, amount: amount, type: txType,
                               categoryId: catId, date: date, note: note,
                               createdAt: now, updatedAt: now)
        try tx.validate()
        try storage.addTransaction(tx)
        return .created(tx.toJSON().json)
    }

    router.put("/transactions/:id") { req, params in
        guard let id = params["id"] else { throw AppError.badRequest("Missing id") }
        guard var tx = storage.findTransaction(id: id) else {
            throw AppError.notFound("Transaction \(id) not found")
        }
        guard let json = parseJSON(req.body) else {
            throw AppError.badRequest("Invalid JSON body")
        }
        tx.applyPatch(json)
        try tx.validate()
        try storage.updateTransaction(tx)
        return .ok(tx.toJSON().json)
    }

    router.delete("/transactions/:id") { _, params in
        guard let id = params["id"] else { throw AppError.badRequest("Missing id") }
        try storage.deleteTransaction(id: id)
        return .noContent()
    }

    // MARK: Categories

    router.get("/categories") { _, _ in
        let cats = storage.allCategories()
        return .ok(JSONValue.array(cats.map { $0.toJSON() }).json)
    }

    router.get("/categories/:id") { _, params in
        guard let id = params["id"] else { throw AppError.badRequest("Missing id") }
        guard let cat = storage.findCategory(id: id) else {
            throw AppError.notFound("Category \(id) not found")
        }
        return .ok(cat.toJSON().json)
    }

    router.post("/categories") { req, _ in
        guard let json = parseJSON(req.body) else {
            throw AppError.badRequest("Invalid JSON body")
        }
        guard let name = json["name"]?.asString else {
            throw AppError.badRequest("Required field: name")
        }
        let id    = json["id"]?.asString ?? generateID()
        let icon  = json["icon"]?.asString  ?? "circle"
        let color = json["color"]?.asString ?? "#6366f1"
        let type  = json["type"]?.asString  ?? "both"
        let now   = currentTimestamp()
        let cat   = Category(id: id, name: name, icon: icon, color: color,
                             type: type, isDefault: false,
                             createdAt: now, updatedAt: now)
        try cat.validate()
        try storage.addCategory(cat)
        return .created(cat.toJSON().json)
    }

    router.put("/categories/:id") { req, params in
        guard let id = params["id"] else { throw AppError.badRequest("Missing id") }
        guard var cat = storage.findCategory(id: id) else {
            throw AppError.notFound("Category \(id) not found")
        }
        guard let json = parseJSON(req.body) else {
            throw AppError.badRequest("Invalid JSON body")
        }
        cat.applyPatch(json)
        try cat.validate()
        try storage.updateCategory(cat)
        return .ok(cat.toJSON().json)
    }

    router.delete("/categories/:id") { _, params in
        guard let id = params["id"] else { throw AppError.badRequest("Missing id") }
        guard let cat = storage.findCategory(id: id) else {
            throw AppError.notFound("Category \(id) not found")
        }
        if cat.isDefault {
            throw AppError.conflict("Cannot delete a default category")
        }
        try storage.deleteCategory(id: id)
        return .noContent()
    }

    // MARK: Settings

    router.get("/settings") { _, _ in
        return .ok(storage.getSettings().toJSON().json)
    }

    router.put("/settings") { req, _ in
        guard let json = parseJSON(req.body) else {
            throw AppError.badRequest("Invalid JSON body")
        }
        var s = storage.getSettings()
        s.applyPatch(json)
        try s.validate()
        try storage.updateSettings(s)
        return .ok(s.toJSON().json)
    }

    router.patch("/settings") { req, _ in
        guard let json = parseJSON(req.body) else {
            throw AppError.badRequest("Invalid JSON body")
        }
        var s = storage.getSettings()
        s.applyPatch(json)
        try s.validate()
        try storage.updateSettings(s)
        return .ok(s.toJSON().json)
    }
}
