.pragma library

var db = null
var icsAdrDb = "icsAddress"
var icsFiltersDb = "icsFilters"
var icsSettingsDb = "icsSettings"
var icsTable = [] // {"id": > 0, "name", "address"}
var filtersTable = [] // {"id", "calId", "item", "field", "value", "srch"//, "filter"
var settingsTable = [] // {"id", "calId", "key", "value"}

/*
  Database
  icsAddress = id INTEGER, name TEXT, address TEXT
  icsSettings = id INTEGER, calId INTEGER, key TEXT, value TEXT
    -calId: calendar id
    -update: 0 - automatic, 1 - manual, 2 - hide // automatic not possible yet -> 0 == 1
    -filter: 0 - leave out, 1 - include // all filters either rejects or accepts all matching records
  icsFilters = id INTEGER, calId INTEGER, item TEXT, field TEXT, value TEXT, srch TEXT//, filter INTEGER
    -calId: id of the calendar that is filtered
    -item: which elements to filter vevent, vtodo, vjournal
    -field: which field of the item is used
    -value: text to be searched in the field
    -srch: search method: "starts" - startsWith, "STARTS" - case sensitive, "ends" - endsWith,
        "ENDS", "index" - indexOf > 0, "INDEX" - case sentive,
        "equal" - ==, "larger" - >, "smaller" - <
*/

// adds calendar urls to icsTable and db
function addCalendar(nick, adr) {
    var id, filter = 0, automatic = 0 // automatic: 0 - automatic; filter = 0 - leave out

    if (db === null) {
        console.log("No database, when adding address " + adr + " (" + nick + ")")
        return
    }
    if (nick == "" || adr == "") {
        console.log("No ics-address ( " + adr + " ) or name ( " + nick + " )")
        return
    }

    if (icsTable.length < 1)
        id = 1
    else
        id = icsTable[icsTable.length-1].id + 1

    addToCalendarDb(id, nick, adr)
    addToCalendarSettings(id, "update", automatic)
    addToCalendarSettings(id, "filter", filter)
    addToCalendarList(id, nick, adr, automatic)

    return

}

function addFilter(cal, item, field, value, criteria) {
    var id = -1
    id = addToFilterDb(cal, item, field, value, criteria)
    if (id >= 0)
        addToFilterList(id, cal, item, field, value, criteria)
    return id
}

function addSetting(cal, key, value) {
    addToSettingsDb(cal, key, value)
    addToSettingsList(cal, key, value)
    return
}

// adds calendar urls to db
function addToCalendarDb(nr, nick, adr) {
    var query = ""
    nick = doubleQuotes(nick)
    adr = doubleQuotes(adr)

    query = "INSERT INTO " + icsAdrDb + " (id, name, address)" +
            " VALUES (" + nr + ", '" + nick + "', '" + adr + "')"

    console.log(query)

    try {
        db.transaction(function(tx){
            tx.executeSql(query)
        })
    } catch (err) {
        console.log("Error adding " + adr + " to " + icsAdrDb + "-table in database: " + err);
    }

    return
}

// adds calendar urls to icsTable
function addToCalendarList(nr, nick, adr, auto) {

    icsTable.push( {"id": nr, "name": nick, "address": adr, "update": auto} )

    return
}

// adds calendar settings to db
// automatic: 0 - automatic, 1 - manual
function addToCalendarSettings(nr, key, value){
    var keyStr = "", valueStr = ""
    var query = ""
    keyStr = doubleQuotes("" + key)
    valueStr = doubleQuotes("" + value)

    query = "INSERT INTO " + icsSettingsDb + " (id, key, value)" +
            " VALUES (" + nr + ", '" + keyStr + "', '" + valueStr + "')"

    console.log(query)

    try {
        db.transaction(function(tx){
            tx.executeSql(query)
        })
    } catch (err) {
        console.log("Error adding (" + keyStr + ", " + valueStr + ") to " + icsSettingsDb + "-table in database: " + err);
    }

    return
}

function addToFilterDb(cal, item, field, value, criteria) { //, action
    var query = "", id = 0, i = 0, N = filtersTable.length
    while (i < N) {
        if (id < filtersTable[i].id)
            id = filtersTable[i].id
        i++
    }
    id++

    query = "INSERT INTO " + icsFiltersDb + " (id, calId, item, field, value, srch)" +
            " VALUES (" + id + ", " + cal + ", '" + item + "', '" + field + "', '" +
            value + "', '" + criteria + "')"

    console.log(query)

    try {
        db.transaction(function(tx){
            tx.executeSql(query)
        })
    } catch (err) {
        console.log("Error adding filter to " + icsFiltersDb + "-table in database: " + err);
        id = -1
    }

    return id
}

function addToFilterList(id, calId, item, field, value, criteria) { //, action
    filtersTable.push({"id": id, "calId": calId, "item": item, "field": field,
                        "value": value, "srch": criteria }) //, "filter": action })
    return
}

function addToSettingsDb(calId, key, value) {
    var query = "", id = 0, i = 0, N = settingsTable.length
    while (i < N) {
        if (id < settingsTable[i].id)
            id = settingsTable[i].id
        i++
    }
    id++

    query = "INSERT INTO " + icsSettingsDb + " (id, calId, key, value)" +
            " VALUES (" + id + ", " + calId + ", '" + key + "', '" +
            value + "')"

    console.log(query)

    try {
        db.transaction(function(tx){
            tx.executeSql(query)
        })
    } catch (err) {
        console.log("Error adding filter to " + icsSettingsDb + "-table in database: " + err);
    }

    return id
}

function addToSettingsList(calId, key, value) {
    var data = { "calId": calId, "key": key, "value": value  }

    return settingsTable.push(data)
}

function createAddressTable() {
    var success = true

    if (db === null)
        return false

    try {
        db.transaction(function(tx){
            tx.executeSql("CREATE TABLE IF NOT EXISTS " + icsAdrDb +
                          " (id INTEGER, name TEXT, address TEXT)");
        });
    } catch (err) {
        console.log("Error in creating table " + icsAdrDb + ": " + err)
        success = false
    }

    return success
}

function createFiltersTable() {
    var success = true

    if (db === null)
        return false

    try {
        db.transaction(function(tx){
            tx.executeSql("CREATE TABLE IF NOT EXISTS " + icsFiltersDb +
                          " (id INTEGER, calId INTEGER, item TEXT, field TEXT," +
                          " value TEXT, srch TEXT, filter INTEGER)");
        });
    } catch (err) {
        console.log("Error in creating table " + icsFiltersDb + ": " + err)
        success = false
    }

    return success
}

function createSettingsTable() {
    var success = true

    if (db === null)
        return false

    try {
        db.transaction(function(tx){
            tx.executeSql("CREATE TABLE IF NOT EXISTS " + icsSettingsDb +
                          " (id INTEGER, calId INTEGER, key TEXT, value TEXT)");
        });
    } catch (err) {
        console.log("Error in creating table " + icsSettingsDb +": " + err)
        success = false
    }

    return success
}

function createTables() {
    var success = true

    if (db === null)
        return false

    if (!createAddressTable())
        success = false

    if (!createFiltersTable())
        success = false

    if (!createSettingsTable())
        success = false

    return success
}

function doubleQuotes(mj) {
    var dum = "" + mj + ""
    //doubles characters ' and "
    dum = dum.replace(/'/g,"''")
    //dum = dum.replace(/"/g,'""')

    return dum
}

// returns -1, if name is not in the table
function findCalendarName(calName) {
    var id = -1, i = 0, N = icsTable.length, str = calName + ""
    while (i < N) {
        if (str.localeCompare(icsTable[i].name)) {
            id = icsTable[i].id
            i = N
        }

        i++
    }

    return id
}

// returns -1, if url is not in the table
function findCalendarUrl(url) {
    var id = -1, i = 0, N = icsTable.length, str = url + ""
    while (i < N) {
        if (str == icsTable[i].address) {
            id = icsTable[i].id
            i = N
        }

        i++
    }

    //console.log("found calendar " + id + " " + i + " : " + url)

    return id
}

// returns {"name", "address"}
function findCalendarData(nr) {
    var i = 0, N = icsTable.length, data = { "name": "", "address": ""}//, "update": -1 }

    while (i < N) {
        if (icsTable.id === nr) {
            data.name = icsTable[i].name
            data.address = icsTable[i].address
            //data.update = icsTable[i].update
            i = N
        }

        i++
    }

    return data
}

function findSetting(calId, key) {
    var i = 0, id=-1, data
    while (i < settingsTable.length) {
        if (settingsTable[i].calId == calId &&
                settingsTable[i].key == key) {
            id = i
            i = settingsTable.length + 1
        }
        i++
    }

    return id
}

function modifyCalendar(id, nick, adr) {

    if (db === null) {
        console.log("No database, when modifying " + adr + " (" + nick + ")")
        return
    }
    if (nick == "" || adr == "") {
        console.log("No ics-address ( " + adr + " ) or name ( " + nick + " )")
        return
    }

    //nick = doubleQuotes(nick)
    //adr = doubleQuotes(adr)

    modifyCalendarDb(id, nick, adr)
    modifyCalendarList(id, nick, adr)

    return

}

function modifyCalendarDb(id, nick, adr) {
    var query = ""

    if(db === null){
        return;
    }

    nick = doubleQuotes(nick)
    adr = doubleQuotes(adr)

    query = "UPDATE " + icsAdrDb + " SET name = '" + nick + "', address = '" +
            adr + "' WHERE id = " + id

    console.log(query)

    try {
        db.transaction(function(tx){
            tx.executeSql(query)
        })
    } catch (err) {
        console.log("Error updating id " + id + " calendar in " + icsAdrDb + "-table: " + err);
    }

    return
}

function modifyCalendarList(id, nick, adr) {
    var i = 0

    while (i < icsTable.length) {
        if (icsTable[i].id === id) {
            icsTable[i].name = nick
            icsTable[i].address = adr
            i = icsTable.length
        }
        i++
    }

    if (i === icsTable.length)
        console.log("Calendar id " + id + " (" + nick + ", " + adr + ") not found.")

    return
}

function modifySetting(cal, key, value) {
    modifySettingDb(cal, key, value)
    modifySettingList(cal, key, value)
    return
}

function modifySettingDb(cal, key, value) {
    var query = ""

    if(db === null){
        return;
    }

    query = "UPDATE " + icsSettingsDb + " SET value = '" + value +
            "' WHERE calId = " + cal + " AND key = '" + key + "'"

    console.log(query)

    try {
        db.transaction(function(tx){
            tx.executeSql(query)
        })
    } catch (err) {
        console.log("Error updating settings in " + icsSettingsDb + "-table: " + err);
    }

    return
}

function modifySettingList(cal, key, value) {
    var i=0, N=settingsTable.length
    while(i < N) {
        if (settingsTable[i].calId == cal && settingsTable[i].key == key) {
            settingsTable[i].value = value
            i = N
        }
        i++
    }

    return i-N
}

// reads icsAdrDb to icsTable
function readAddressDb() {
    var N = 0, i = 0 // number of rows read
    var dbRows

    if(db === null) {
        console.log("Error, database not open.")
        return
    }

    try {
        db.transaction(function(tx){
            dbRows = tx.executeSql("SELECT * FROM " + icsAdrDb)
            N = dbRows.rows.length
        })
    } catch (err) {
        console.log("Error reading " + icsAdrDb +"-table in database: " + err)
    };

    console.log("found " + N + " rows in " + icsAdrDb)

    while (icsTable.length > 0) {
        icsTable.pop()
    }

    if (N > 0) {
        for (i = 0; i < N; i++ ){
            addToCalendarList(dbRows.rows[i].id, dbRows.rows[i].name, dbRows.rows[i].address)
            console.log("row " + i + " " + dbRows.rows[i].id + " " + dbRows.rows[i].name
                        + " " + dbRows.rows[i].address)
        }
    }

    return N

}

function readDb() {
    readAddressDb()
    readFiltersDb()
    readSettingsDb()
    return
}

function readFiltersDb() {
    var N = 0, i = 0 // number of rows read
    var dbRows

    if(db === null) {
        console.log("Error, database not open.")
        return
    }

    try {
        db.transaction(function(tx){
            dbRows = tx.executeSql("SELECT * FROM " + icsFiltersDb)
            N = dbRows.rows.length
        })
    } catch (err) {
        console.log("Error reading " + icsFiltersDb + "-table in database: " + err)
    };

    console.log("found " + N + " rows in " + icsFiltersDb)

    while (filtersTable.length > 0) {
        filtersTable.pop()
    }

    if (N > 0) {
        for (i = 0; i < N; i++ ){
            // (id, calId, item, field, value, criteria)
            addToFilterList(dbRows.rows[i].id, dbRows.rows[i].calId, dbRows.rows[i].item,
                            dbRows.rows[i].field, dbRows.rows[i].value, dbRows.rows[i].srch)
            console.log("row " + i + " " + dbRows.rows[i].id + " " + dbRows.rows[i].item
                        + " " + dbRows.rows[i].field)
        }
    }

    return N
}

function readSettingsDb() {
    var N = 0, i = 0 // number of rows read
    var dbRows

    if(db === null) {
        console.log("Error, database not open.")
        return
    }

    try {
        db.transaction(function(tx){
            dbRows = tx.executeSql("SELECT * FROM " + icsSettingsDb)
            N = dbRows.rows.length
        })
    } catch (err) {
        console.log("Error reading " + icsSettingsDb + "-table in database: " + err)
    };

    console.log("found " + N + " rows in " + icsSettingsDb)

    while (settingsTable.length > 0) {
        settingsTable.pop()
    }

    if (N > 0) {
        for (i = 0; i < N; i++ ){
            // (id, calId, item, field, value, criteria)
            addToSettingsList(dbRows.rows[i].calId, dbRows.rows[i].key, dbRows.rows[i].value)
        }
    }

    return N
}

function readSetting(calId, key) {
    var i=0, N=settingsTable.length, result

    while (i<N) {
        if (settingsTable[i].id === calId)
            if (settingsTable[i].key === key) {
                result = settingsTable[i].value
                i = N
            }

        i++
    }

    return result
}

function removeCalendar(nr) {
    if (db === null) {
        console.log("Database not open.")
        return
    }

    removeCalendarFromDb(nr)
    removeCalendarFromList(nr)

    return
}

function removeCalendarFromDb(nr){

    if(db === null){
        return;
    }

    try {
        db.transaction(function(tx){
            tx.executeSql("DELETE FROM " + icsAdrDb + " WHERE id = " + nr)
        })
    } catch (err) {
        console.log("Error removing id " + nr + " address from " + icsAdrDb + "-table: " + err);
    }

    return
}

function removeCalendarFromList(nr) {
    var i = 0
    while (i < icsTable.length) {
        if (icsTable[i].id === nr) {
            icsTable.splice(nr,1)
            i = icsTable.length
        }
        i++
    }

    if (i === icsTable.length)
        console.log("address id " + nr + " not found")

    return
}

function removeFilter(id) {
//   icsFilters = id INTEGER, calId INTEGER, item TEXT, field TEXT, value TEXT, srch TEXT//, filter INTEGER
    removeFilterDb(id)
    removeFilterList(id)
    return
}

function removeFilterDb(id) {
    if(db === null){
        return;
    }

    try {
        db.transaction(function(tx){
            tx.executeSql("DELETE FROM " + icsFiltersDb + " WHERE id = " + id)
        })
    } catch (err) {
        console.log("Error removing " + id + " filter from " + icsFiltersDb + "-table: " + err);
    }

    return
}

function removeFilterList(id) {
    var i = 0, N = filtersTable.length
    while (i < N) {
        if (filtersTable[i].id == id) {
            filtersTable.splice(i, 1)
            i = N
        }

        i++
    }
    return
}

function qqqqq(tt) {
    var query = "", dbRows, i=0

    if(db === null){
        return;
    }

    //query = "ALTER TABLE " + icsSettingsDb + " ADD COLUMN calId"
    query = "PRAGMA table_info('" + tt + "')"
    //query = "SELECT sql FROM sqlite_master WHERE type='table' AND name = '" + tt + "'"

    console.log(query)

    try {
        db.transaction(function(tx){
            dbRows = tx.executeSql(query)
            console.log(" <> " + JSON.stringify(dbRows))
        })
    } catch (err) {
        console.log("Error : " + err);
    }

    while (i < dbRows.rows.length) {
        console.log(" qqq " + JSON.stringify(dbRows.rows[i]))
        i++
    }

    return
}
