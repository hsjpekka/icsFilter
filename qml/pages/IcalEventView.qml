import QtQuick 2.0
import Sailfish.Silica 1.0
//import Nemo.Configuration 1.0
//import "../scripts/utils.js" as Utils

// {"year", "day", "clock", "type", "location", "description", "include"}
Item {
    id: icalEventView
    width: parent? parent.width : Screen.width
    height: Theme.fontSizeMedium*4

    property alias count: calendarData.count//isCppModel? eventsListModelcpp.count : eventsListModelJS.count
    //property bool isCppModel: false
    property alias listMargin: eventsView.x
    property alias model: calendarData//isCppModel? eventsListModelcpp : eventsListModelJS
    property color leaveOutColor: Theme.secondaryColor
    property color readInColor: Theme.highlightColor
    //property string showAddressUrl: "http://maps.google.com/maps?f=q&q="
    property string icsOriginal: ""
    property string icsModified: ""

    Component {
        id: eventListDelegate
        ListItem {
            id: eventsListItem
            width: parent.width
            height: eventDay.height

            property bool accept: include

            Row {
                width: parent.width
                spacing: Theme.paddingSmall

                Icon {
                    id: acceptIcon
                    source: eventsListItem.accept? "image://theme/icon-s-checkmark" :
                                                   "image://theme/icon-s-decline"
                    color: eventsListItem.accept? readInColor: leaveOutColor
                }

                Label {
                    id: eventDay
                    text: day
                    color: eventsListItem.accept ? Theme.highlightColor : Theme.secondaryHighlightColor
                }

                Label {
                    id: eventClock
                    text: clock
                    color: eventDay.color
                }

                Label {
                    id: eventName
                    text: txt
                    color: eventDay.color
                }

            }
            /*
            Item {
                id: eventLocationItem
                height: eventLocation.height
                visible: eventDesc.visible
                anchors {
                    left: eventDay.left //eventDay.horizontalCenter
                    leftMargin: Theme.paddingMedium
                    top: eventDay.bottom
                    topMargin: Theme.paddingMedium
                    right: parent.right
                    rightMargin: Theme.horizontalPageMargin
                }
                Icon {
                    id: locationIcon
                    source: "image://theme/icon-m-location"
                    color: Theme.primaryColor
                    height: eventLocation.font.pixelSize
                    width: height
                }

                Label {
                    id: eventLocation
                    x: 0.5*eventDay.width + eventDay.anchors.leftMargin
                    width: parent.width - x
                    visible: eventDesc.visible
                    color: Theme.primaryColor
                    text: location
                    wrapMode: Text.WrapAtWordBoundaryOrAnywhere
                }

                MouseArea {
                    anchors.fill: parent
                    onClicked: {
                        var url = showAddressUrl + eventLocation.text
                        console.log("avaa osoitteen " + url)
                        Qt.openUrlExternally(url)
                    }
                }
            }

            TextArea {
                id: eventDesc
                anchors {
                    left: eventDay.horizontalCenter
                    top: eventLocation.text === "" ? eventDay.bottom : eventLocationItem.bottom
                    topMargin: Theme.paddingSmall
                    right: parent.right
                }
                color: Theme.secondaryHighlightColor
                readOnly: true
                visible: false
                text: description
                onClicked: {
                    visible = !visible
                }
            }
            onClicked: {
                eventDesc.visible = !eventDesc.visible
            }
            // */

        }

    }

    ListModel{
        id: calendarData
        ListElement {
            include: false
            day: "date"
            clock: "time"
            txt: "txt"
        }
        property bool firstTime: true

        function add(d, t, txt) {
            if (firstTime) {
                clear();
                firstTime = false;
            }

            return append({"include": false, "day" : d, "clock": t,
                              "txt": txt});
        }

        function check(d, t, txt) {
            var i, cDate = "", cTime = "", cTxt = "";
            i=0;
            while (i < count) {
                cDate = get(i).day;
                cTime = get(i).clock;
                cTxt = get(i).txt;
                //console.log("modify if", cDate, "=", d, " ", cTime, "=", t, " ", count)

                if (cDate.toLowerCase() === d.toLowerCase() &&
                        cTime.toLowerCase() === t.toLowerCase() &&
                        cTxt.toLowerCase() === txt.toLowerCase()) {
                    setProperty(i, "include", true);
                    i = count;
                }
                i++;
            }
            return (i > count);
        }
    }

    SilicaListView{
        id: eventsView
        width: parent.width - 2*x
        height: parent.height
        spacing: Theme.paddingMedium
        //x: Theme.horizontalPageMargin
        clip: true

        model: calendarData//isCppModel? eventsListModelcpp : eventsListModelJS
        delegate: eventListDelegate

        //section.delegate: SectionHeader {
        //    text: section
        //}
        //section.property: "year"

        VerticalScrollDecorator{}
    }

    // finds the next component, returns the line number
    // returns -line numbe''''r if end of calendar reached
    function componentSearch(lineArray, i0) {
        var i, N, reCalBegin, reCalEnd, reCmp;
        N = -1;
        i = (i0 >= 0)? i0 : 0;
        reCmp = /^begin\s*:\s*/i;
        reCalBegin = /^begin\s*:\s*[v]*calendar/i;
        reCalEnd = /^end\s*:\s*[v]*calendar/i;
        while (i < lineArray.length) {
            N = i;
            if (reCalEnd.test(lineArray[i])) { //if there is more than one calendar in the file
                N = -i;
                i = lineArray.length;
            } else if (reCmp.test(lineArray[i]) &&
                       !reCalBegin.test(lineArray[i])) {
                i = lineArray.length;
            }
            i++;
        }
        return N;
    }

    // stores the component in the listmodel
    // returns the line number of <end:vcomponent>
    function componentStore(lineArray, i0, isOrig) {
        var cmp, edate, edesc, etime, i, iN, keyValue, p, props, endExp, s, strs;
        if (i0 >= lineArray.length) {
            return -1;
        }
        // read the component type for end of component
        strs = lineArray[i0].split(":");
        if (strs.length < 2) {
            console.log("rivi = " + lineArray[i0]);
            return i0;
        }
        cmp = strs[1].trim();
        endExp = new RegExp("^end\\s*:\\s*" + cmp,"i");
        //console.log(lineArray[i0], strs[0], strs[1], cmp);
        // read component properties
        i = i0;
        props = [];
        while (i < lineArray.length) {
            if (endExp.test(lineArray[i])) { // end of component
                iN = i;
                i = lineArray.length;
            } else {
                keyValue = keyAndValue(lineArray[i]);
                props.push({"key": keyValue[0], "value": keyValue[1]});
            }
            i++;
        }
        console.log(props.length, props[0].key, props[0].value);

        // select the properties to store in the list
        // date, time, title
        // title = description || summary || categories
        for (i in props) {
            p = props[i].key.toLowerCase();
            if (p === "dtstart") {
                strs = props[i].value.split("T"); // strs[0] = 20230429, strs[1] = hhmmss(Z)
                s = strs[0];
                edate = s.substr(-2) + "." + s.substr(-4, 2) + ".";
                if (strs.length > 1) {
                    s = strs[1];
                    etime = s.substr(0, 2) + ":" + s.substr(2, 2);
                } else {
                    etime = "";
                }
            } else if (p === "summary" ||
                       (p === "description" && edesc === "")) {
                edesc = props[i].value;
            }
        }
        // if description and summary are not given
        if (edesc === "") {
            for (i in props) {
                if (props[i].key.toLowerCase() === "category") {
                    edesc = props[i].value;
                }
            }
        }

        console.log("store/modify", ",", isOrig, ",", edate, ",", etime, ",", edesc)

        if (isOrig) {
            calendarData.add(edate, etime, edesc);
        } else {
            calendarData.check(edate, etime, edesc);
        }

        return iN;
    }

    function keyAndValue(line) {
        var i, j, key, value;
        key = readKey(line);
        value = readValue(line);
        return [key, value];
    }

    function processIcs(fileStr, isOrig) {
        var cmp, i, lines, N, newLines, qq;

        console.log("täällä", isOrig);
        lines = fileStr.split("\r\n");
        if (lines.length < 2) {
            lines = fileStr.split("\n");
            if (lines.lenght > 1) {
                if (isOrig) {
                    console.log("iCalendar-file has wrong end of lines.");
                } else {
                    console.log("Modified iCalendar-file has wrong end of lines.");
                }
            }
        }

        newLines = unFoldLines(lines);
        N = newLines.length;
        if (newLines === undefined || newLines.length === undefined || N < 1) {
            if (isOrig) {
                console.log("Error when unfolding the iCalendar-file.");
            } else {
                console.log("Error when unfolding the modified iCalendar-file.");
            }

            return -1;
        }

        console.log(isOrig, lines.length, N);
        i = 0;
        while (i < N) {
            i = componentSearch(newLines, i);
            if (i < 0) { // end of vcalendar
                i = N;
            } else {
                console.log("store component, line " + i + ", " + isOrig);
                i = componentStore(newLines, i, isOrig);
            }
            i++;
        }

        return;
    }

    function readKey(line) {
        var i, j, result = line;
        i = line.indexOf(":");
        j = line.indexOf(";");
        if (j < 0 && i > 0) {
            result = line.substring(0, i);
        } else if (j > 0 && (j < i || i < 0)) {
            result = line.substring(0, j);
        }
        return result;
    }

    function readValue(line) {
        var i, j, k, result;
        i = line.indexOf(":");
        j = line.indexOf(";");
        if (i < 0) {
            result = "";
        } else if ((j < 0 && i > 0) || (j > i && i > 0)) { // no ; or ; is part of the value
            result = line.substring(i + 1);
        } else { // some property parameters found
            k = line.indexOf('"'); // is there dquoted parameters
            while (k < i && k > 0) { // a dquoted parameter value found
                k = line.indexOf('"', k + 1); // end of dquote
                if (k > 0) {
                    i = line.indexOf(':', k + 1); // first : after the dquote
                    k = line.indexOf('"', k + 1); // next dquote?
                }
            }
            if (i > 0) {
                result = line.substring(i);
            }
        }
        return result;
    }

    function refresh() {
        var result = 0;
        if (icsOriginal.length > 0) {
            calendarData.clear();
            processIcs(icsOriginal, true);
            if (icsModified.length > 0) {
                processIcs(icsModified, false);
                result = 2;
            } else {
                result = 1;
                console.log("suodatettu tiedosto tyhjä")
            }
        } else {
            console.log("tyhjä alkuperäistiedosto")
        }

        return result;
    }

    //if a line starts with a white space, combine the line and the previous line
    function unFoldLines(lineArray) {
        var cmbLine, i, line0, line1, newArray = [];
        i = lineArray.length - 1;
        while (i > 0) {
            line1 = lineArray[i];
            if (line1.charAt(0) === " ") { // || chr === "\t") {
                line0 = lineArray[i-1];
                cmbLine = line0.concat(line1.substring(1));
                lineArray[i-1] = cmbLine;
                lineArray[i] = "";
            }
            i--;
        }
        i=0;
        while (i < lineArray.length - 1) {
            if (lineArray[i] !== "") {
                newArray.push(lineArray[i]);
            }
            i++;
        }

    return newArray;
    }
}
