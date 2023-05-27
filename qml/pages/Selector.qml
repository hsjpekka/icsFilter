import QtQuick 2.0
import Sailfish.Silica 1.0
import QtQuick.LocalStorage 2.0
import Nemo.Notifications 1.0
import "../scripts/ical.js" as Ical
import "../scripts/dbase.js" as DataB
import "../scripts/utils.js" as Utils

Page {
    id: page

    allowedOrientations: Orientation.All
    Component.onCompleted: {
        modelCalendars.clear()
        openDatabase()
        //DataB.qqqqq(DataB.icsAdrDb)
        //DataB.qqqqq(DataB.icsFiltersDb)
        //DataB.qqqqq(DataB.icsSettingsDb)
        readSettings()
        if (modelCalendars.count >= 1) {
            var calNr = 0
            //fetchCalendar(modelCalendars.get(calNr).calName, modelCalendars.get(calNr).calUrl, false)
            fetchCalendar2(modelCalendars.get(calNr).calUrl, false, modelCalendars.get(calNr).calName)
            //console.log("combo " + currentIndex)
            calendarAddress.text = modelCalendars.get(calNr).calUrl
        }
        //console.log("starts reading calendars")
        //updateAll()
        /*
        https://haagankarhut.nimenhuuto.com/calendar/ical?auth[user_id]=284538&auth[ver]=02&auth[signature]=71b4f7c43381a8146f954d03d8498af910a9aa93
        https://haagankarhut.nimenhuuto.com/calendar/ical?auth[user_id]=284538&auth[ver]=02&auth[signature]=6016624e2c33411bccc02f7a791e5a7c88740214
        // */

        starting = false
    }

    //property var db: null
    property int rivi: -1
    property bool starting: true
    property bool isCppComponent: false
    property date ddate
    property string exportDir: "/home/nemo/Downloads/" // "$HOME/Downloads/"
    property string version: "0.1.3"
    property string icsString: ""
    property string filterFile: ""
    onIsCppComponentChanged: {
        fetchCalendar2(calendarAddress.text, false, cbCalendars.value)
    }

    ListModel {
        id: modelCalendars
        ListElement {
            calName: ""
            calUrl: ""
            calNr: 0
            update: 0 //0 - automatic update, 1 - manual, 2 - hide
            filter: 0 //events that match filters are: 0 - left out, 1 - included
        }
    }

    Notification {
        id: note
    }

    SilicaFlickable {
        anchors.fill: parent
        contentHeight: column.height

        PullDownMenu {
            MenuItem {
                text: isCppComponent? "vaihda js-palikkaan" : "vaihda c++-funktioihin"
                onClicked: {
                    isCppComponent = ! isCppComponent
                }
            }
            MenuItem {
                text: qsTr("event filters")
                onClicked: {
                    var url = calendarAddress.text
                    var filterPage =  pageStack.push(Qt.resolvedUrl("Filters.qml"), {
                                       "calendarLbl": cbCalendars.value,
                                       "calId": DataB.findCalendarUrl(calendarAddress.text),
                                       "icsFile": icsString })
                    filterPage.closing.connect( function() {
                        icsString = filterPage.icalModified
                        //processFile(url, icsString, false)
                        return
                    } )
                }
            }

            MenuItem {
                text: qsTr("calendars")
                onClicked: {
                    var calPage = pageStack.push(Qt.resolvedUrl("Calendars.qml"))
                    calPage.closing.connect( function() {
                        readCalendarNames()
                        return
                    } )
                }
            }

        }

        PushUpMenu {
            MenuItem {
                text: qsTr("export")
                //text: qsTr("export %1").arg(cbCalendars.value)
                onClicked: {
                    exportToCalendar(Ical.icsFile, cbCalendars.value)
                    //note.previewSummary = "note's summary"
                    //note.previewBody = "preview body" //Utils.icsJson.VCALENDAR.PRODID
                    //note.publish()
                    //popUpNote.publish(Utils.icsJson.VCALENDAR.PRODID)
                }
            }

            MenuItem {
                text: qsTr("show ics-file")
                onClicked: {
                    pageStack.push(Qt.resolvedUrl("IcsFile.qml"),
                                   {"calendar": cbCalendars.value, "address": calendarAddress.text,
                                       "original": Ical.icsFile, "filtered": Ical.filtered })

                }
            }

            MenuItem {
                text: version
            }
        }

        // Place our content in a Column.  The PageHeader is always placed at the top
        // of the page, followed by our content.
        Column {
            id: column

            width: parent.width
            spacing: Theme.paddingMedium

            PageHeader {
                title: qsTr("UI Template")
            }

            ComboBox {
                id: cbCalendars
                width: parent.width
                enabled: modelCalendars.count > 0
                label: enabled ? qsTr("calendar") : qsTr("no calendars")
                menu: ContextMenu {
                    Repeater {
                        model: modelCalendars
                        MenuItem {
                            text: calName
                        }
                    }
                }
                onCurrentIndexChanged: {
                    console.log("combo " + currentIndex)
                    var address = modelCalendars.get(currentIndex).calUrl
                    //var name = modelCalendars.get(currentIndex).calName
                    calendarAddress.text = address
                    eventsView.model.clear()
                    //fetchCalendar(modelCalendars.get(currentIndex).calName, address, false)
                    //fetchCalendar2(address, false, name)
                    fetchCalendar2(address, false, value)
                }

            }

            Label {
                id: calendarAddress
                width: parent.width - 2*x
                text: ""
                color: Theme.secondaryHighlightColor
                x: Theme.horizontalPageMargin
                wrapMode: Text.WrapAtWordBoundaryOrAnywhere
            }

            SectionHeader {
                text: qsTr("events") + " " + eventsView.count
            }

            IcalEventView {
                id: eventsView
                width: parent.width
                height: page.height - y//Theme.fontSizeMedium*6//parent.height - y
                //isCppModel: isCppComponent
            }

        }
    }

    // fetchCalendar2
    function exportToCalendar(icsFile, calName) {
        var fileName = ""
        if (exportDir.charAt(exportDir.length - 1) !== "/")
            exportDir += "/"

        fileName = exportDir + encodeURIComponent(calName) + ".ics"

        console.log("writing ics-file")

        Utils.fileWrite(fileName, icsFile)
        console.log("opening calendar")
        Qt.openUrlExternally(fileName)

        return
    }

    // fetchCalendar2
    function fetchCalendar2(url, isUpdate, name) {
        Ical.getIcalFile(url, function (url, icalFile) {

            //Ical.icsFile = icalFile // stores the latest file
            //Ical.icsJson = Ical.icalToJson(icalFile) // stores the latest file
            //icalJson = Ical.icsJson
            icsString = icalFile; // stores the latest file
            console.log(url, isUpdate, name, "\n", icsString.substring(0,20), " ...")
            //processFile(url, icalFile, isUpdate, name);
            return;
        });

        return;
    }

    // fetchCalendar2
    function processFile(url, icalFile, update, lbl) {
        var exportFile, name, calNr, defInclude;
        console.log("tiedoston käsittely alkaa");
        calNr = DataB.findCalendarUrl(url);
        if (isCppComponent) {
            if (lbl === undefined) {
                lbl = "";
            }

            calNr = -1;
            icalFile = icsFilter.filterIcs(lbl, icalFile, vainTestaukseen());
            //console.log("ics-tiedosto:" + icalFile);
        }
        if (calNr === -1 || DataB.findSetting(calNr, "filter") !== 0) {
            defInclude = true;
        } else {
            defInclude = false;
        }

        if (isCppComponent) {
            exportFile = icalFile
            Ical.icsFile = icalFile
        }
        exportFile = Ical.filterFile(calNr, icalFile, defInclude, DataB.filtersTable,
                                function(event) {
                                    eventsView.append(event);
                                    return;
                                } );

        Ical.filtered = exportFile;
        if (update) {
            name = DataB.findCalendarData(calNr).name; // {"name", "address"}
            exportToCalendar(exportFile, name);
        }

        console.log("tiedoston käsittely päättyy");
        return;
    }

    function openDatabase() {
        var success = true

        if(DataB.db == null) {
            try {
                DataB.db = LocalStorage.openDatabaseSync("icals", "0.1", "ical-calendars", 10000);
            } catch (err) {
                console.log("Error in opening the database: " + err);
                return false
            };
        }

        DataB.createTables()

        DataB.readDb()

        return success
    }

    function readSettings() {
        readCalendarNames()
        readCalendarSettings()
        //updateAll()

        return
    }

    function readCalendarNames() {
        var i = 0, N, calNr, show

        modelCalendars.clear()
        N = DataB.icsTable.length

        while (i < N) {
            calNr = DataB.icsTable[i].id
            if (DataB.readSetting(calNr,"update") != 2)
                modelCalendars.append({"calName": DataB.icsTable[i].name,
                                          "calUrl": DataB.icsTable[i].address, "calNr": calNr })

            console.log("i " + i + " name " + DataB.icsTable[i].name)
            i++
        }

        return
    }

    function readCalendarSettings() {
        var i=0, N, j=0, M = modelCalendars.count, calId, key, value

        N = DataB.settingsTable.length

        while (i < N){
            calId = DataB.settingsTable[i].calId
            key = DataB.settingsTable[i].key
            value = DataB.settingsTable[i].value
            j = 0
            while (j < M) {
                if (modelCalendars.get(j).calNr == calId) {
                    if (key === "update")
                        modelCalendars.get(j).update = value
                    if (key === "filter")
                        modelCalendars.get(j).filter = value

                }

                j++
            }

            i++
        }

        return
    }

    //updating all does not work as long as exporting is done by Qt.openUrlExternally
    function updateAll() {
        var i=0
        while (i < DataB.icsTable.length) {
            if (DataB.icsTable[i].update === 0) {
                Ical.getIcalFile(DataB.icsTable[i].address, function (icalFile, icalJson) {
                    console.log("read " + DataB.icsTable[i].name)
                    exportToCalendar(icalFile, DataB.icsTable[i].name)
                } )
            }

            i++
        }

        return
    }

    // shows events in listView
    function writeEvents(calNr, jsonObj) {
        var eventList, event, str = "", title = ""
        var i = 0

        //jsonStr += "}"
        //console.log("  " + jsonStr)
        //str = encodeURI(jsonStr)
        //str = Ical.checkString(str)

        //console.log(" = " + str)
        //cal=JSON.parse(str)

        //console.log(" == " + jsonObj.VCALENDAR.PRODID)

        eventList = jsonObj.VCALENDAR.vEvents
        event = eventList.items

        //console.log(" == list.count = " + eventList.count)

        if (eventList.count == 0) {
            eventsView.append({ "day": "  .  .", "clock": "  :", "type": "-", "description": "",
                                       "year": "", "location": "", "include": false
                                   })
        }

        while (i < eventList.count) {
            //eventsView.model.append({"lineNumber": event[i].DTSTART,
            //                           "line": event[i].DESCRIPTION })
            addEvent(calNr, event[i])
            i++
        }

        //console.log("")

        //console.log(" ## i = " + i)

        return
    }

    QtObject {
        function qqaddEvent(calNr, event) {
            var date, qq, ms, ifMatches = false//, min=60*1000
            var evItem = {"year": "", "day": "", "clock": "", "type": "", "location": "",
                "description": "", "include": ifMatches }//, "showDesc": false }
            var time = event.DTSTART, title = event.CATEGORIES, loc = decodeURI(event.LOCATION),
                desc = decodeURI(event.DESCRIPTION)
            if (title.length < 1)
                title = event.SUMMARY
            title = decodeURI(title)

            // timeZone should be checked at the event time, not when the function is called
            ms = Ical.icsTimeToMs(time)  // in UTC 0

            date = new Date(ms)

            //console.log("loc: " + loc + ", time: " + time)
            //console.log(" ooo " + time + ", " + title + ", " + desc.slice(0, 10) + ", " + ms)
            //console.log(" ooo " + date.getDate() + "." + date.getMonth() + ".")

            evItem.year = date.getFullYear() + ""
            evItem.day = date.getDate() + "." + (date.getMonth() + 1) + "."

            qq = date.getHours()
            if (qq < 10)
                evItem.clock = "0" + qq
            else
                evItem.clock = qq + ""

            qq = date.getMinutes()
            if (qq < 10)
                evItem.clock += ":0" + qq
            else
                evItem.clock += ":" + qq

            evItem.type = title

            evItem.location = Utils.replaceChars(loc)
            evItem.description = Utils.replaceChars(desc)

            ifMatches = DataB.readSetting(calNr, "filter")
            evItem.include = Utils.filterEvent(event, calNr, DataB.filtersTable, ifMatches)

            //console.log(" ooo " + evItem.clock + " # " + title + " # " + evItem.description)

            eventsView.append(evItem)

            return
        }

        function qqcomposeIcsFile(originalLines, filteredEvents) {
            var lines
        }

        // fetches new ics-file, prints contents to eventview, and if (update) exportToCalendar
        function qqfetchCalendar(name, url, update) {
            Ical.getIcalFile(url, function (url, icalFile) {
                var filteredJson, filteredIcs, icalJson
                var jsonObj = Ical.icalToJson(icalFile)//(Ical.icalFile)
                var N, i = 0, str = "", calNr = DataB.findCalendarUrl(url)
                var lines = []

                Ical.icsFile = icalFile // stores the latest file
                Ical.icsJson = Ical.icalToJson(icalFile) // stores the latest file
                icalJson = Ical.icsJson
                icsString = icalFile

                //console.log(" -- =0= -- " + icalFile.length + " calNr " + calNr)
                lines = icalFile.split("\r\n");
                if (lines.length < 2)
                    lines = icalFile.split("\n");

                //console.log(" -- =2= -- " + lines.length)

                Utils.copyArray(lines, Utils.icsLines) // stores the latest uploaded file
                Ical.icsFile = icalFile
                //console.log(" -- =2b= -- ")
                //Utils.copyArray(jsonRows, Utils.jsonLines)
                Ical.icsJson = jsonObj // stores the latest uploaded file

                //filteredIcs = filterEvents(id, icalJson)
                //console.log(" -- =3= -- ")

                writeEvents(calNr, icalJson)

                //if (update)
                //    exportToCalendar(icalFile, name)

                //console.log(" -- =4= -- ")

                return
            } )

            return
        }

        // fetchCalendar2
        function qqfilterFile(calNr, orig, includeDef, fTable, addEvent) { //splits the file into an array of lines
            var file = "", lines = [], N, i=0, skip, k0 = 0

            lines = orig.split("\r\n")
            if (lines.length < 2)
                lines = orig.split("\n")

            Ical.unFoldLines(lines)
            k0 = Ical.removeEmptyLines(lines)
            N = lines.length

            if (k0 > 0)
                console.log("removed " + k0 + " folded or empty lines")

            //if (DataB.findSetting(calNr, "filter") === 0)
            //    includeDef = false
            //else
            //    includeDef = true

            while (i < N) {
                skip = filterLine(calNr, includeDef, lines, i, fTable, addEvent)
                if (skip === 0) {
                    console.log("++ " + lines[i])
                    file += foldLine(lines[i]) + "\n"
                } else {
                    for (k0 = 0; k0 < skip; k0++) {
                        console.log("-- " + lines[i+k0])
                    }

                    i += skip
                }
                i++
            }

            return file
        }

        // fetchCalendar2
        function qqfoldLine(line) {
            var max = 72, result = "", i=0, j=max

            while (j < line.length) {
                result += line.slice(i, j) + "\n "
                i = j
                j += max - 1
            }

            result += line.slice(i, line.length)

            return result
        }

        // fetchCalendar2
        function qqeditEventLines(lines, first, last) {
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

        // fetchCalendar2
        function qqmatchEventFilter( fProp, fType, fValue, eProp, eOpts, eValue) {
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

        // fetchCalendar2
        function qqmatchingFilters(calNr, prop, opts, value, filterTable) {
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

        // fetchCalendar2
        function qqfilterEvent(calNr, includeDef, lines, nr0, fTable, addEvent) {
            var match = false, i=0, j=0, nr1, event, eventLines, k=0, dum, prop = [], opt = [],
            os = [], val = [], current = [], result, curOpt = []

            nr1 = findEventEnd(lines, nr0)
            eventLines = editEventLines(lines, nr0, nr1) // combines multiline data - prop;opt:val

            while (i < eventLines.length) {
                //current = []
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
                    match = matchingFilters(calNr, current[0], curOpt, current[current.length - 1], fTable)

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

        // fetchCalendar2
        function qqshowEvent(prop, nOps, opt, val, inOrOut, addEvent) {
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
                    ms = Ical.icsTimeToMs(val[i])
                    date = new Date(ms)
                    event.year = date.getFullYear() + ""
                    //event.day = date.toLocaleString(undefined, {"month": "2-digit", "day": "2-digit"})
                    event.day = date.getDate() + "." + date.getMonth() + "."
                    event.clock = Utils.clockString(ms)
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

        // fetchCalendar2
        // returns the number of lines to be filtered out
        function qqfilterLine(calNr, includeDef, lines, i, fTable, addEvent) {
            var skip = 0, lc, isEvent = true, beginEvent = /^\s*begin\s*:\s*vevent/i

            if ( beginEvent.test(lines[i]) ) {
                skip = filterEvent(calNr, includeDef, lines, i+1, fTable, addEvent)
            }

            return skip
        }

        // fetchCalendar2
        function qqfindEventEnd(lines, nr0) {
            var i=nr0, end = false, endEvent = /^\s*end\s*:\s*vevent/i
            while (i < lines.length && !end) {
                end = endEvent.test(lines[i])
                i++
            }

            return i-1
        }

        // fetchCalendar2
        // returns [property, opt, opt, ..., value]
        function qqreadIcsLine(str) {
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

        function qqreadQuote(str, i0) {    // returns the end of the quote starting at i0
            // finds the end of the quote starting at or after i0
            var j, k = -1, escape = false

            j = str.indexOf('"', i0) + 1

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

        /*
        function showCalendar(url) {
            Ical.getIcalFile(url, function(icsFile) {
                                 showIcsFile(icsFile)
                                 showJsonLines(Ical.icalToJson(icsFile))
                             })
        }

        function showCalendar_v0(url) {
            Ical.getIcalFile(url,
                             function() {
                                 showIcsFile()
                                 showJsonLines(Ical.icalToJson(Ical.icalFile))
                             })
        }
        // */

        /*
        function filterEvents(calId, icalJson) {
            var ics = "", i = 0, N = icalJson.vEvents.count, eventList = [], event

            while (i < N) {
                event = icalJson.vEvents.items[i]
                if (!isFilteredOut(event))
                    eventList.push(event)
                i++
            }

            icalJson.vEvents.count = eventList.length
            icalJson.vEvents.items = eventList

            return ics
        }

        function isFilteredOut(event) {
            var isOut = false
            // should do the filtering
            return isOut
        }
        // */

        /*
        Component {
            id: lineView

            ListItem {
                id: riviNaytto
                width: icsNaytto.width
                height: txtLine.contentHeight + 2*txtLine.anchors.topMargin
                onClicked: {
                    rivi = icsNaytto.indexAt(mouseX, y + mouseY)
                }

                Label {
                    id: lNr
                    text: lineNumber
                    color: Theme.highlightColor
                    anchors {
                        left: parent.left
                        top: parent.top
                        leftMargin: Theme.paddingSmall
                        topMargin: txtLine.anchors.topMargin
                    }
                }

                Rectangle {
                    color: "transparent"
                    //width: parent.width
                    border.color: Theme.secondaryHighlightColor
                    border.width: 1
                    radius: Theme.paddingMedium
                    height: txtLine.contentHeight + 2*txtLine.anchors.topMargin
                    anchors{
                        left: parent.left
                        top: parent.top
                        right: parent.right
                        topMargin: 0
                        leftMargin: lNr.width + lNr.anchors.leftMargin + 0.5*Theme.paddingSmall
                        rightMargin: Theme.paddingSmall //leftMargin
                    }
                }

                Label {
                    id: txtLine
                    color: Theme.highlightColor
                    text: line
                    wrapMode: TextInput.WrapAtWordBoundaryOrAnywhere
                    anchors {
                        left: parent.left
                        top: parent.top
                        right: parent.right
                        topMargin: 0.5*Theme.paddingSmall
                        leftMargin: lNr.width + lNr.anchors.leftMargin + Theme.paddingSmall
                        rightMargin: Theme.paddingMedium //leftMargin
                    }
                }

            }//jj

        }
        // */
    }

    function vainTestaukseen() {
        // vain testaukseen
        // ========>
        // fileName = filterPath + "icsFilters.json";
        var filterFileContents = "{ \"calendars\": [" +
                "  { \"label\": \"haka\"," +
                "    \"idProperty\": \"X-WR-CALNAME\"," +
                "    \"idValue\": \"Haagan Karhut - https://haagankarhut.nimenhuuto.com/\"," +
                "    \"reminder\": \"120\"," +
                "    \"dayreminder\": \"18:00\"," +
                "    \"filters\": [" +
                "    { \"component\": \"vevent\"," +
                "      \"action\": \"accept\"," +
                "      \"properties\": [" +
                "      { \"property\": \"categories\"," +
                "        \"type\": \"string\"," +
                "        \"combination\": \"single\"," +
                "        \"values\": [" +
                "        { \"value\": \"matsi\"," +
                "          \"criteria\": \"s\"" +
                "        }]" +
                "      }]" +
                "    }]" +
                "  }," +
                "  { \"label\": \"futis\"," +
                "    \"idProperty\": \"X-WR-CALNAME\"," +
                "    \"idValue\": \"AFRY futis - https://afryfutis.nimenhuuto.com/calendar/ical\"," +
                "    \"reminder\": \"120\"," +
                "    \"dayreminder\": \"18:00\"," +
                "    \"filters\": [" +
                "    { \"component\": \"vevent\"," +
                "      \"action\": \"reject\"," +
                "      \"properties\": [" +
                "        { \"property\": \"categories\"," +
                "          \"type\": \"string\"," +
                "          \"combination\": \"single\"," +
                "          \"values\": [" +
                "          { \"value\": \"ottelu\"," +
                "            \"criteria\": \"s\"" +
                "          }," +
                "          { \"value\": \"muu\"," +
                "            \"criteria\": \"s\"" +
                "          }]" +
                "        }," +
                "        { \"property\": \"dtstart\"," +
                "          \"type\": \"time\"," +
                "          \"combination\": \"single\"," +
                "          \"values\": [" +
                "          { \"value\": \"08:00\"," +
                "            \"criteria\": \"!=\"" +
                "          }]" +
                "        }]" +
                "    }]" +
                "  }]" +
                "}";
        // <=====
        return filterFileContents;
    }
}
