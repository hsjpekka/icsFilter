.pragma library
var events = []
var icsLines = [], jsonLines = []

function arrayToString(array) {
    var str = "", N = array.length, i = 0
    while (i < N) {
        str += array[i] + "\n"
        i++
    }
    return str
}

function clearArray(arr) {
    var i = 0, N = arr.length

    while (i < N) {
        arr.pop()
        i++
    }

    return
}

function copyArray(from, to) {
    var i=0, N=from.length
    clearArray(to)
    while (i < N) {
        to.push(from[i])
        i++
    }

    return
}

function copyArrayReckless(from, to) {
    to = from.splice(0, from.lenght)

    return
}

function fileOpen(url) {
    var request = new XMLHttpRequest();
    request.open("GET", url, false);
    request.send(null);
    return request.responseText;
}

function fileWrite(url, text) {
    var request = new XMLHttpRequest();
    request.onreadystatechange = function () {
        console.log("onreadystatechange: " + " ~ " + request.readyState)
        //if (request.readyState > 0) {
            //if (request.status === 200) {
                //request.send(text);
            //}
        //}
    }

    request.open("PUT", url, false);
    console.log(" oo " + request.readyState)
    request.send(text);

    return request.readyState;
}

function filterEvent(event, calId, filtersTable, defVal) { // if filter matches, return defVal
    var j = 0, match = false, M = filtersTable.length

    while (j < M) { // check each event against the filters
        if (calId === filtersTable[j].calId) {
            //console.log("   " + filtersTable[j].calId + ", " +
              //          filtersTable[j].item.toUpperCase() + ", " +
                //        filtersTable[j].field.toUpperCase() + ", " +
                  //      filtersTable[j].srch.toUpperCase() + ", " +
                    //    filtersTable[j].value.toUpperCase())

            if (filtersTable[j].item.toUpperCase() === "VEVENT") {
                if (filtersTable[j].field.toUpperCase() === "CATEGORIES")
                    match = isMatching(event.CATEGORIES,
                                        filtersTable[j].srch,
                                        filtersTable[j].value)
                else if (filtersTable[j].field.toUpperCase() === "SUMMARY")
                    match = isMatching(event.SUMMARY,
                                        filtersTable[j].srch,
                                        filtersTable[j].value)
            }

        }

        if (match === true)
            j = M
        else
            j++
    }

    console.log("  viltteröity " + M + ", " + j + ", osuma " + match)

    if (match) {
        return defVal
    }

    return !defVal

}

function isMatching(eventString, filterType, value){
    // search method: "starts" - startsWith, "STARTS" - case sensitive,
    // "ends" - endsWith, "ENDS", "contains" - indexOf, "CONTAINS" - case sentive,
    // "equal" - ==, "EQUALS", "larger" - >, "smaller" - <
    var result = false, es = "", vs = ""

    //console.log("isMatching " + eventString + ", " + filterType + " - " + value)

    if (filterType === "starts") {
        es = eventString.toLocaleLowerCase()
        vs = value.toLocaleLowerCase()
        result = es.startsWith(vs)
    } else if (filterType === "STARTS") {
        result = eventString.startsWith(value)
    } else if (filterType === "ends") {
        es = eventString.toLocaleLowerCase()
        vs = value.toLocaleLowerCase()
        result = es.endsWith(vs)
    } else if (filterType === "ENDS") {
        result = eventString.endsWith(value)
    } else if (filterType === "contains") {
        es = eventString.toLocaleLowerCase()
        vs = value.toLocaleLowerCase()
        if (es.indexOf(vs) >= 0)
            result = true
    } else if (filterType === "CONTAINS") {
        if (eventString.indexOf(value) >= 0)
            result = true
    } else if (filterType === "equals") {
        es = eventString.toLocaleLowerCase()
        vs = value.toLocaleLowerCase()
        if (es == vs)
            result = true
    } else if (filterType === "EQUALS") {
        if (eventString === value)
            result = true
    } else if (filterType === "smaller") {
        if (eventString < value)
            result = true
    } else if (filterType === "larger") {
        if (eventString > value)
            result = true
    }

    es = eventString.toLocaleLowerCase()
    vs = value.toLocaleLowerCase()
    //if (es == vs)
      //  console.log("" + es + " == " + vs + ", result = " + result)
    //else
      //  console.log("" + es + " != " + vs + ", result = " + result)

    return result
}

function rplChar(str, oldChar, newChar) {
    var i = str.indexOf(oldChar)

    while (i >= 0) {
        str = str.replace(oldChar, newChar)
        i = str.indexOf(oldChar)
    }

    return str
}

function replaceChars(str) {
    str = rplChar(str, "\\n", "\n")
    str = rplChar(str, "\\,", ",")

    return str
}
