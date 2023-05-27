.pragma library

//var icalFile = "tyhjä";
//var icalFileLines = [];
//var separator = ":";
//var begin = "BEGIN";
//var end = "END";
var icsFile // the latest uploaded file
var icsJson // the file converted to a JSON-object
var filtered // icsFile without filtered events

/*
function qqkokeilu() {
    var mj = '{ "DTSTAMP" : "20190628T180222Z", ' +
            '"UID" : "12618568@Nimenhuuto.com", "DTSTART" : "20190906T070000Z",' +
            '"DTEND" : "20190906T090000Z", "CREATED" : "20190625T132623Z",' +
            '"DESCRIPTION" : "All day event in Tampere\n\nhttps://poyryfutis.nimenhuuto.com/events/12618568",' +
            '"LAST-MODIFIED" : "20190625T171726Z", "LOCATION" : "Tampere\, Tampere",' +
            '"SEQUENCE" : 13863, "SUMMARY" : "Pöyry futis: Pöyry football tournament",' +
            '"URL" : "https://poyryfutis.nimenhuuto.com/events/12618568" }'
    var mj2 = '{ "DTSTAMP" : "20190628T180222Z", ' +
            '"UID" : "12618568@Nimenhuuto.com", "DTSTART" : "20190906T070000Z",' +
            '"DTEND" : "20190906T090000Z", "CREATED" : "20190625T132623Z",' +
            '"DESCRIPTION" : "All day event in Tampere \n\nhttps://poyryfutis.nimenhuuto.com/events/12618568" }'
    var jjj

    mj2 = encodeURI(mj)
    //console.log(mj2)
    mj2 = checkString(mj2)
    //console.log(mj2)

    jjj = JSON.parse(mj2)
    console.log(" "  + jjj.DESCRIPTION )

    return
}

function qqriveja(file){
    var lines
    lines = file.split("\n");

    console.log("rivejä " + lines.length)

    return lines.length;
    //return jsonIcal;
}

function qqaddLine(line, isCard, vCalendar, vTodos, vEvents, vJournals, vTimezones) {
    var name = "", value = "", keyword = "", i = 0, str = "", dum = ""

    i = line.indexOf(separator) // where the value starts
    name = line.substring(0, i)
    value = line.substring(i + 1)
    i = name.indexOf(";") // does the property have parameters?
    if (i < 0) {
        keyword = name
    } else {
        keyword = name.substring(0, i)
    }

    //console.log(name + " | " + value + " ; " + keyword)
    value = checkString(value)
    //console.log("" + value)

    if (keyword.toLocaleUpperCase() === begin) {
        str = '"' + value + '": {'
        dum = value.toLocaleUpperCase()
        //  || dum === "" || dum === "" || dum === ""
        if (dum === "VEVENT") {
            isCard.isEvent = true
            vEvents.push("{")
            str = ""
        } else if (dum === "VTODO") {
            isCard.isTodo = true
            vTodos.push("{")
            str = ""
        } else if (dum === "VJOURNAL") {
            isCard.isJournal = true
            vJournals.push("{")
            str = ""
        } else if (dum === "VTIMEZONE") {
            isCard.isTimeZ = true
            vTimezones.push("{")
            str = ""
        }
    } else if (keyword.toLocaleUpperCase() === end) {
        str = "},"
        if (isCard.isEvent) {
            isCard.isEvent = false
            dum = vEvents.pop()
            if (dum.charAt(dum.length -1) === ",")
                dum = dum.slice(0,-1)
            vEvents.push(dum + "\n" + str)
            //vEvents.push(str)
            str = ""
        } else if (isCard.isTodo) {
            isCard.isTodo = false
            dum = vTodos.pop()
            if (dum.charAt(dum.length -1) === ",")
                dum = dum.slice(0,-1)
            vTodos.push(dum + "\n" + str)
            //vTodos.push(str)
            str = ""
        } else if (isCard.isJournal) {
            isCard.isJournal = false
            dum = vJournals.pop()
            if (dum.charAt(dum.length -1) === ",")
                dum = dum.slice(0,-1)
            vJournals.push(dum + "\n" + str)
            //vJournals.push(str)
            str = ""
        } else if (isCard.isTimeZ) {
            isCard.isTimeZ = false
            dum = vTimezones.pop()
            if (dum.charAt(dum.length -1) === ",")
                dum = dum.slice(0,-1)
            vTimezones.push(dum + "\n" + str)
            //vTimezones.push(str)
            str = ""
        }
    } else {
        if (keyword != name) { // property has parameters
            str = addOptions(name, value)
        } else {
            if ( !isNaN(value) )
                str = '"' + name + '" ' + separator + ' ' + value + ','
            else
                str = '"' + name + '" ' + separator + ' "' + value + '",'
        }

        if (isCard.isEvent) {
            dum = vEvents.pop()
            vEvents.push(dum + "\n" + str)
            str = ""
        } else if (isCard.isTodo) {
            dum = vTodos.pop()
            vTodos.push(dum + "\n" + str)
            str = ""
        } else if (isCard.isJournal) {
            dum = vJournals.pop()
            vJournals.push(dum + "\n" + str)
            str = ""
        } else if (isCard.isTimeZ) {
            dum = vTimezones.pop()
            vTimezones.push(dum + "\n" + str)
            str = ""
        }
    }

    //console.log(">_" + str + "_<")

    return str
}

function qqaddOptions(key, val) {
    var str = "", s = "", i=0, j=0
    str = '"' + key.slice(0, key.indexOf(";")) + '" : {\n  "opt" : {\n '
    s = key.slice(key.indexOf(";")+1, key.length)

    while (s.length > 0) {
        i = s.indexOf(";")
        if (i < 0)
            i = s.length

        j = s.indexOf("=")
        if (j < 0)
            j = s.length

        if (j < i){
            str += '  "' + s.slice(0, j) + '" : "' + s.slice(j + 1, i) + '"\n'
        } else {
            str += '  "' + s.slice(0,i) + ' : true\n'
        }

        if (i === s.length -1)
            s = ""
        else
            s = s.slice(i+1)
    }

    str += "},\n"
    str += ' "value" : "' + val + '"\n}'

    return str
}

function qqchangeString(str, change, to) {
    var parts = str.split(change), result = ""
    var N = parts.length, i = 0
    //console.log(" " + change + " , " + to + " - " + N)

    result = parts[0]
    while ( i < N-1 ){
        result += to
        result += parts[i+1]
        i++
    }

    return result
    //return str
}

//adds '\' in front of "'"
//adds '\' in front of "\"
function qqcheckString(line) {
    //var (""), char = "{",
    var result = ""

    result = changeString(line, "%7B", "{")
    result = changeString(result, "%20", " ")
    result = changeString(result, "%22", '"')
    result = changeString(result, "%7D", '}')
    result = changeString(result, "%5B", "[")
    result = changeString(result, "%5D", "]")
    result = changeString(result, "%0A", " ")

    return result
}

//translates the ics-file to json-file
//returns the json-file as an array of strings
function qqcompose(icalLines) {
    var strJson = ["{"]
    var N = icalLines.length, i = 0
    var addStr = "", prevStr = "", str2 = ""
    var firstItem = true
    var isCard = { "isEvent": false, "isTodo": false, "isJournal": false, "isTimeZ": false }
    var vCalendar = []; //id, name, + vcalendar properties: version, prodid, calscale, method
    var vTodos = []; //vCalId, + vtodo properties:
    var vEvents = []; //vCalId, + vevent properties: sum, uid, seq, stat, transp, rrule, dtstart, dtend, dtstamp, ctgr, loc, geo, desc, url
    var vJournals = []; //vCalId, + vJournal:
    var vTimezones = []; //vCalId, + vtimezone:

    while (i < N) {
        prevStr = strJson[strJson.length - 1]
        addStr = addLine(icalLines[i], isCard, vCalendar, vTodos, vEvents, vJournals, vTimezones)

        if (addStr.charAt(0) === "}" && prevStr.length > 2) {
            if (prevStr.charAt(prevStr.length - 1) === ',') {
                str2 = prevStr.slice(0,-1)
                strJson.pop()
                strJson.push(str2)
            }
        }
        if (addStr !== "") {
            if (i === icalLines.length -1) {
                addStr = addStr.slice(0, addStr.length - 1)
            }

            strJson.push(addStr)
        }
        i++
    }

    composeEvents(strJson, vEvents)
    composeTodos(strJson, vTodos)
    composeJournals(strJson, vJournals)
    composeTimezones(strJson, vTimezones)

    strJson.push("}")

    return strJson
}

function qqcomposeEvents(js, vEvents) {
    var i=0, s = "", str = '"vEvents" : {\n' + ' "count": ' + vEvents.length +
            ',\n "items": [ ';
    s = js.pop() // removes the end "}" of the calendar
    if (s.charAt(s.length-1) !== "}") {
        console.log("'}' missing.")
    } else {
        s = js.pop()
    }

    s += ","
    js.push(s)
    js.push(str)

    while (i < vEvents.length - 1){
        js.push(vEvents[i])
        i++
    }

    if (i < vEvents.length) {
        s = vEvents[i]
        if (s.charAt(s.length - 1) === ',')
            s = s.slice(0,-1)
        js.push(s)
    }

    js.push("]") // pair for "items: ["
    js.push("}") // pair for "vEvent: {"
    js.push("}") // one was removed in the beginning of this function

    return
}

function qqcomposeJournals(js, vJournals) {
    var i=0, s = "", str = '"vJournals" : {\n' + ' "count": ' + vJournals.length +
            ',\n "items": [ ';
    s = js.pop()
    if (s.charAt(s.length-1) !== "}") {
        console.log("'}' missing.")
    } else {
        s = js.pop()
    }

    s += ","
    js.push(s)
    js.push(str)

    while (i < vJournals.length - 1){
        js.push(vJournals[i])
        i++
    }

    if (i < vJournals.length) {
        s = vJournals[i]
        if (s.charAt(s.length - 1) === ',')
            s = s.slice(0,-1)
        js.push(s)
    }

    js.push("]") // pair for "items: ["
    js.push("}") // pair for "vJournal: {"
    js.push("}") // one was removed in the beginning of this function

    return
}

function qqcomposeTimezones(js, vTimezones) {
    var i=0, s = "", str = '"vTimezones" : {\n' + ' "count": ' + vTimezones.length +
            ',\n "items": [ ';
    s = js.pop()
    if (s.charAt(s.length-1) !== "}") {
        console.log("'}' missing.")
    } else {
        s = js.pop()
    }

    s += ","
    js.push(s)
    js.push(str)

    while (i < vTimezones.length - 1){
        js.push(vTimezones[i])
        i++
    }

    if (i < vTimezones.length ) {
        s = vTimezones[i]
        if (s.charAt(s.length - 1) === ',')
            s = s.slice(0,-1)
        js.push(s)
    }

    js.push("]") // pair for "items: ["
    js.push("}") // pair for "vTimezone: {"
    js.push("}") // one was removed in the beginning of this function

    return
}

function qqcomposeTodos(js, vTodos) {
    var i = 0, N = 0, s = "", str = ""
    s = js.pop()
    if (s.charAt(s.length-1) !== "}") {
        console.log("'}' missing.")
    } else {
        s = js.pop()
    }

    s += ","
    js.push(s)

    str = '"vTodos" : {\n' + ' "count": ' + vTodos.length + ',\n "items": [ '
    js.push(str)

    while (i < vTodos.length - 1){
        js.push(vTodos[i])
        i++
    }

    if (i < vTodos.length) {
        s = vTodos[i]
        if (s.charAt(s.length - 1) === ',')
            s = s.slice(0,-1)
        js.push(s)
    }

    js.push("]") // pair for "items: ["
    js.push("}") // pair for "vTodo: {"
    js.push("}") // one was removed in the beginning of this function

    return
}

//returns a json-object
function qqicalToJson(file){
    var i, N, str = "", str2 = "";
    var icalLines = [], jsonLines = [], jsonObj;
    //splits the file into rows
    icalLines = file.split("\r\n");
    if (icalLines.length < 2)
        icalLines = file.split("\n");

    //console.log("icalToJson rivejä " + icalLines.length);

    unFoldLines(icalLines);

    removeEmptyLines(icalLines);

    jsonLines = compose(icalLines);

    i = 0
    N = jsonLines.length
    while (i < N) {
        str += jsonLines[i] + "\n"
        i++
    }
    console.log(" = = " + str.length + " N= " + N)

    str2 = encodeURI(str)
    //console.log(" = = = 1")
    str = checkString(str2)
    console.log(" = = = "  + str.length + " ## " + str2.length + " - " + jsonLines[0])

    jsonObj = JSON.parse(str)
    console.log(" = = = 3")

    //return;
    return jsonObj;
}

function qqjsonToIcal(icsObj) {
    var ics = ""

    return ics
}
//*/

function clearArray(arr) {
    var i = 0, N = arr.length

    while (i < N) {
        arr.pop()
        i++
    }

    //console.log(" poistettuja " + N)

    return
}

function clockString(ms) {
    var date = new Date(ms), hours, minutes, result = ""
    hours = date.getHours()
    minutes = date.getMinutes()
    if (hours < 10) {
        result = "0"
    }
    result += hours + ":"

    if (minutes < 10) {
        result += "0"
    }
    result += minutes

    return result
}

function editEventLines(lines, first, last) {
    // compresses multiline cells into single line
    var i=last, str, k, eventStrings = [], result = []

    while (i >= first) {
        str = ""
        while (lines[i].charAt(0) === " ") { // || lines[i].charAt(0) == "\t" || lines[i].charAt(0) == "\n") {
            //if (lines[i].length > 1)
                str = lines[i].slice(1) + str
            i--
        }
        str = lines[i] + str

        eventStrings.push(str)

        i--
    }

    k = eventStrings.length - 1
    while(k >= 0) {
        result.push(eventStrings[k])
        k--
    }

    return result
}

function filterEvent(calNr, includeDef, lines, nr0, fTable, addEvent) {
    var match = false, i=0, j=0, nr1, eventLines, prop = [], opt = [],
        os = [], val = [], current = [], result, curOpt = []

    nr1 = findEventEnd(lines, nr0)
    eventLines = editEventLines(lines, nr0, nr1) // combines multiline data - prop;opt:val

    while (i < eventLines.length) {
        current = readIcsLine(eventLines[i]) // property, opt, opt, ..., value // line: prop;opt*:val

        j = 0
        curOpt = []
        while (j < current.length - 2) {
            opt.push(current[j]) // add to the list of options
            curOpt.push(current[j])
            j++
        }
        prop.push(current[0]) //name of property on line i
        os.push(j) //number of options on line i
        val.push(current[current.length - 1]) //value of property on line i

        if (!match)
            match = matchingFilters(calNr, current[0], curOpt, current[current.length - 1],
                                    fTable)

        i++
    }

    if (includeDef) { // event is included, if it does not match any filter
        showEvent(prop, os, opt, val, !match, addEvent)
    } else {
        showEvent(prop, os, opt, val, match, addEvent)
    }

    if (match)
        result = nr1 - nr0 + 1
    else
        result = 0

    return result
}

function filterFile(calNr, orig, includeDef, fTable, addEvent) { //splits the file into an array of lines
    var file = "", lines = [], N, i=0, skip, k0 = 0;

    lines = orig.split("\r\n");
    if (lines.length < 2) {
        lines = orig.split("\n");
    }

    unFoldLines(lines);
    k0 = removeEmptyLines(lines);
    N = lines.length;

    if (k0 > 0) {
        console.log("removed " + k0 + " folded or empty lines");
    }

    while (i < N) {
        skip = filterLine(calNr, includeDef, lines, i, fTable, addEvent);
        if (skip === 0) {
            //console.log("++ " + lines[i])
            file += foldLine(lines[i]) + "\n";
        } else {
            //for (k0 = 0; k0 < skip; k0++) {
            //    console.log("-- " + lines[i+k0])
            //}

            i += skip;
        }
        i++;
    }

    return file;
}

// returns the number of lines to be filtered out
function filterLine(calNr, includeDef, lines, i, fTable, addEvent) {
    var skip = 0, lc, isEvent = true, beginEvent = /^\s*begin\s*:\s*vevent/i

    if ( beginEvent.test(lines[i]) ) {
        skip = filterEvent(calNr, includeDef, lines, i+1, fTable, addEvent)
    }

    return skip
}

function findEventEnd(lines, nr0) {
    var i=nr0, end = false, endEvent = /^\s*end\s*:\s*vevent/i
    while (i < lines.length && !end) {
        end = endEvent.test(lines[i])
        i++
    }

    return i-1
}

function foldLine(line) { // splits line into max 72 char long lines
    var max = 72, result = "", i=0, j=max

    while (j < line.length) {
        result += line.slice(i, j) + "\n "
        i = j
        j += max - 1
    }

    result += line.slice(i, line.length)

    return result
}

//update the icalfile
function getIcalFile(url, whenReady){
    var xhttp = new XMLHttpRequest();

    xhttp.onreadystatechange = function () {
        console.log(" " + xhttp.readyState + " ~ " + xhttp.statusText)
        if (xhttp.readyState === 4) {
            if (xhttp.status === 200) {
                //icsFile = xhttp.responseText; //store latest file
                //icsJson = icalToJson(icsFile);
                //whenReady()
                whenReady(url, xhttp.responseText)
            }
        }
    }

    xhttp.open("GET", url, true)
    xhttp.send();

    return
}

// strng = yyyymmddThhmmssZ or yyyymmddThhmmss
// or strng = { "opt": { ["TZID": xxx, ...] }, "value": timestring }
function icsTimeToMs(strng) {
    // if strng ends with 'Z' time is already given in UTC 0, otherwise timeZone is added
    var str = [], clockSeparator = "T", c1 = 0, chrs = 4, year, month, day, hh, mm, ss, ms
    var dd, dateStr = "", clockString = "", utc = "Z", local = false, min = 60*1000
    var timeString = "", zone = "", timeZone //timeZone in minutes (UTC +2 = -120)

    if (strng.opt === undefined) // no parameters in DTSTART
        timeString = strng
    else {
        timeString = strng.value
        if (strng.opt.TZID !== undefined) // if timezone is defined, the corresponding line must be in VTIMEZONE-list
            zone = strng.opt.TZID
    }

    str = timeString.split(clockSeparator)
    if (str.count < 2){
        console.log("Error in time format:" + strng)
        //return
    }

    dateStr = str[0]
    clockString = str[1] // HHMMSS or HHMMSSZ

    if (clockString.indexOf(utc) < 0)
        local = true
    else
        local = false

    // read date
    chrs = 2 //DD
    c1 = dateStr.length - chrs
    day = dateStr.slice(c1, c1 + chrs)
    c1 -= chrs
    month = dateStr.slice(c1, c1 + chrs) - 1 // month 0 - 11 in javascript
    year = dateStr.slice(0, c1)

    // read time
    if (clockString.length === 0) { //full day event
        hh = -1
        mm = -1
        ss = -1
        dd = new Date(year, month, day, 0, 0, 0, 0) // uses local time
    } else {
        c1 = 0
        hh = clockString.slice(c1, c1 + chrs)
        c1 += chrs
        mm = clockString.slice(c1, c1 + chrs)
        c1 += chrs
        ss = clockString.slice(c1, c1 + chrs)

        dd = new Date(year, month, day, hh, mm, ss, 0) // assumes local time
        if (!local) {
            timeZone = dd.getTimezoneOffset()
            dd.setTime(dd.getTime() - timeZone*min)
        }

    }

    //if (timeZone === undefined)
    //    timeZone = new Date().getTimezoneOffset()


    ms = dd.getTime()

    if (local) // if time string does not end with "Z", it is given as local time
        ms += timeZone*min // time at UTC 0

    //console.log(" ### " + dateStr + ", " + year + ", " + month + ", " + day + ", " + hh + ", " +
    //            mm + ": " + local )

    return ms
}

function matchEventFilter( fProp, fType, fValue, eProp, eOpts, eValue) {
    var fstr, estr, result = false
    if (fProp.toLowerCase() === eProp.toLowerCase()) {
        if (fType === "starts") {
            fstr = fValue.toLocaleLowerCase()
            estr = eValue.toLocaleLowerCase()
            result = estr.startsWith(fstr)
        } else if (fType === "STARTS") {
            result = eValue.startsWith(fValue)
        } else if (fType === "ends") {
            fstr = fValue.toLocaleLowerCase()
            estr = eValue.toLocaleLowerCase()
            result = estr.endsWith(fstr)
        } else if (fType === "ENDS") {
            result = eValue.endsWith(fValue)
        } else if (fType === "contains") {
            fstr = fValue.toLocaleLowerCase()
            estr = eValue.toLocaleLowerCase()
            result = estr.endsWith(fstr)
        } else if (fType === "CONTAINS") {
            result = eValue.endsWith(fValue)
        } else if (fType === "equals") {
            fstr = fValue.toLocaleLowerCase()
            estr = eValue.toLocaleLowerCase()
            result = (fstr === estr)? true : false
        } else if (fType === "EQUALS") {
            result = (fstr === estr)? true : false
        } else if (fType === "smaller") {
            fstr = fValue.toLocaleLowerCase()
            estr = eValue.toLocaleLowerCase()
            result = (fstr < estr)? true : false
        } else if (fType === "SMALLER") {
            result = (fstr < estr)? true : false
        } else if (fType === "larger") {
            fstr = fValue.toLocaleLowerCase()
            estr = eValue.toLocaleLowerCase()
            result = (fstr > estr)? true : false
        } else if (fType === "LARGER") {
            result = (fstr > estr)? true : false
        }

    }

    return result
}

function matchingFilters(calNr, prop, opts, value, filterTable) {
    var i = 0, N = 0, result = false
    N = filterTable.length

    while (i <  N) {
        if (calNr === filterTable[i].calId) {
            if (filterTable[i].item.toUpperCase() === "VEVENT") {
                result = matchEventFilter(filterTable[i].field,
                                     filterTable[i].srch, filterTable[i].value,
                                     prop, opts, value)
                if (result)
                    i = N
            }
        }

        i++
    }

    return result
}

// returns [property, opt, opt, ..., value]
function readIcsLine(str) {
    var reg = /[^\s]/, n1 = 0, n2 = 0, n3 = 0, n4 = 0
    var prop = "", val = "", opt = [], result = []
    // line: prop;opt*:val
    // property
    n1 = str.indexOf(":")
    n2 = str.indexOf(";")
    if (n1 < n2 || n2 < 0) { // no options
        prop = str.slice(0, n1)
    } else { // options, n1 - location of separator :, n2 - location of separator ;
        n2++
        while (n2 < n1) {
            n1 = str.indexOf(":", n2)
            n3 = str.indexOf('"', n2)
            n4 = str.indexOf(";", n2)
            if (n4 < 0) { // no more ';'
                n4 = n1
            }
            if (n3 < n4 && n3 > 0) { // a quotation as the value of the option
                n3 = readQuote(str, n3)
                n4 = str.indexOf(";", n3)
                n1 = str.indexOf(":", n3)
                if (n4 < 0) {
                    n4 = n1
                }
            }
            opt.push(str.slice(n2, n4))
            n2 = n4 + 1

        }
    }

    // value
    if (n1 >= 0) {
        val = str.slice(n1+1, str.length)
    }

    // return [property, options, value]
    result.push(prop)
    n3 = 0
    while (n3 < opt.length) {
        result.push(opt[n3])
        n3++
    }
    result.push(val)

    return result
}

function readQuote(str, i0) {    // returns the end of the quote starting at i0
    // finds the end of the quote starting at or after i0
    var j, k = -1, escape = false

    j = str.indexOf('"', i0-1) + 1 // if i0 is not ", finds the next one

    while (j < str.length) {
        if (str.charAt(j) === '\\')
            escape = !escape
        else {
            if (!escape && str.charAt(j) === '"'){
                k = j
                j = str.length
            }
            escape = false
        }
        j++
    }

    return k // -1 if quote end not found
}

//removes empty lines from icalFileLines
//counts the number of empty lines, copies full lines to a new array
function removeEmptyLines(icalLines) {
    var i = 0, emptyLines = 0, lines = icalLines.length
    var lineArray = [], str

    if (lines < 1)
        return 0;

    while (i < lines) {
        str = icalLines[i]
        if (str.length === 0)
            emptyLines++
        else
            lineArray.push(str)
        i++
    }

    clearArray(icalLines)

    for(i=0; i < lineArray.length; i++) {
        icalLines.push(lineArray[i])
    }

    //console.log("removed " + emptyLines + " folded or empty lines")

    return emptyLines
}

function showEvent(prop, nOps, opt, val, inOrOut, addEvent) {
    // {"year", "day", "clock", "type", "location", "description", "include"}
    var i=0, j, nProp = prop.length, ms, pStr, event = {}, date

    event.year = ""
    event.day = ""
    event.clock = ""
    event.type = ""
    event.location = ""
    event.description = ""
    event.include = inOrOut

    while (i < nProp) {
        pStr = prop[i].toUpperCase()
        if (pStr === "DTSTART") {
            ms = icsTimeToMs(val[i])
            date = new Date(ms)
            event.year = date.getFullYear() + ""
            //event.day = date.toLocaleString(undefined, {"month": "2-digit", "day": "2-digit"})
            event.day = date.getDate() + "." + (date.getMonth() +1) + "."
            event.clock = clockString(ms)
        } else if (pStr === "LOCATION") {
            event.location = val[i]
        } else if (pStr === "CATEGORIES") {
            event.type = val[i]
        } else if (pStr === "DESCRIPTION") {
            event.description = val[i]
        }

        i++
    }

    //eventsView.append(event)
    addEvent(event)

    return
}

//if a line starts with a white space, combine the line and the previous line
//returns the number of combined lines (0 or 1)
function unFold(icalLines, lineNr) {
    var line1 = icalLines[lineNr], chr
    var line0, combined = 0, cmbLine

    if (lineNr > 0) {
        line0 = icalLines[lineNr-1]
    } else
        return 0

    chr = line1.charAt(0)
    if (chr === " ") { // || chr === "\t") {
        cmbLine = line0.concat(line1.substring(1))
        icalLines[lineNr-1] = cmbLine
        icalLines[lineNr] = ""
        combined = 1
    }

    return combined

}

function unFoldLines(icalLines) {
    var i = icalLines.length - 1, N=0;
    while (i >= 0) {
        if (unFold(icalLines, i) > 0)
            N++
        i--
    }

    //if (N > 0)
    //    console.log("tyhjennettyjä rivejä " + N )

    return
}
