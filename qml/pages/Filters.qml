import QtQuick 2.0
import Sailfish.Silica 1.0
import QtQuick.LocalStorage 2.0
import "../scripts/ical.js" as Ical
import "../scripts/dbase.js" as DataB
import "../scripts/utils.js" as Utils

Page {
    id: page
    allowedOrientations: Orientation.All
    Component.onCompleted: {
        console.log("calendar name " + calendarLbl + ", id " + calId + "." )
        // print filters
        // print filtered events
        readCalendarFilters(calId)
        filterIcsFile()
        eventsView.refresh()
        refresh()
        cbFilteringCriteria.currentIndex = 0
        cbFilteringCriteria.selectedComparison = criteriaStrings.get(cbFilteringCriteria.currentIndex).comparison
        cbPropertyType.currentIndex = 0
        cbPropertyType.ptype = cbPropertyType.pstring
        cbFilterComponent.currentIndex = 0
        cbFilterField.currentIndex = 0
    }
    Component.onDestruction: {
        closing()
    }

    property alias calendarLbl: calendarName.text
    property int calId
    //property alias filtersOut: true
    property string icsFile: ""
    //property string icalFilter: ""
    property string icsModified: ""
    property var jsonFilter: {"calendars": []};

    readonly property bool isAccept: true

    signal closing()
    signal refresh()

    ListModel {
        id: filterModel
        //{"icsComponent", "icsProperty", "icsPropType",
        //"icsValMatches", "icsCriteria", "icsValue"}

        /*
        // check if filter type has changed (pass or block, or or and)
        function checkComponentChanges(comp, reject, propMatches){
            var i=0, current;
            while (i < count) {
                current = get(i);
                if (comp === current.icsComponent) {
                    if (current.icsReject !== reject ||
                            current.icsPrpMatches !== propMatches){
                        setProperty(i, "icsReject", reject);
                        setProperty(i, "icsPrpMatches", propMatches);
                    }
                }
                i++;
            }
            return;
        } //*/

        function checkPropertyChanges(comp, prop, valMatches){
            var i=0, current;
            while (i < count) {
                current = get(i);
                if (comp === current.icsComponent && prop === current.icsProperty) {
                    if (current.icsValMatches !== valMatches){
                        setProperty(i, "icsValMatches", valMatches);
                    }
                }
                i++;
            }
            return;
        }

        function addFilter(comp, prop, propType,//, reject, propMatches, prop, propType,
                           valMatches, crit, val) {
            //checkComponentChanges(comp, reject, propMatches);
            checkPropertyChanges(comp, prop, valMatches);
            append({"icsComponent": comp, //"icsReject": reject,
                       //"icsPrpMatches": propMatches,
                       "icsProperty": prop,
                       "icsPropType": propType, "icsValMatches": valMatches,
                       "icsCriteria": crit, "icsValue": val
                   });
            console.log("lisää " + comp + ", " + ", " + prop + ", "
                        + propType + ", " + valMatches + ", "
                        + crit + ", " + val)
            return;
        }

        function modifyFilter(i, comp, prop, //reject, propMatches, prop,
                              propType, valMatches, crit, val) {
            //checkComponentChanges(comp, reject, propMatches);
            checkPropertyChanges(comp, prop, valMatches);
            if (i >= 0 && i < count) {
                set(i, {"icsComponent": comp, //"icsReject": reject,
                        //"icsPrpMatches": propMatches,
                        "icsProperty": prop,
                        "icsPropType": propType, "icsValMatches": valMatches,
                        "icsCriteria": crit, "icsValue": val
                    });
            } else {
                console.log("index out of filterModel range");
            }

        }
    }

    Component {
        id: filterDelegate
        ListItem {
            contentHeight: Theme.itemSizeSmall
            menu: ContextMenu {
                MenuItem {
                    text: qsTr("delete")
                    onClicked: {
                        console.log("i " + listViewFilters.currentIndex + " index " + index)
                        filterModel.remove(index)
                    }
                }
                MenuItem {
                    text: qsTr("modify")
                    onClicked: {
                        addFilter(index)
                    }
                }
            }
            onClicked: {
                console.log("filtteri " + icsComponent + ", " + icsProperty + ", " + icsCriteria + ", " + icsValue)
                cbFilterComponent.currentIndex = calendarComponents.getIndex(icsComponent)
                cbFilterComponent.value = cbFilterComponent.currentItem.text
                //calendarOptions.isPassFilter = icsReject
                //calendarOptions.isAnd = (icsValMatches > 0.5)
                allOrAnyValue.checked = icsValMatches > 0.5
                //cbFilterComponent.fcValue = icsComponentNr(icsComponent)
                cbFilterField.value = icsProperty
                if (icsPropType === cbPropertyType.pstring) {
                    cbPropertyType.currentIndex = 0
                } else if (icsPropType === cbPropertyType.pdate) {
                    cbPropertyType.currentIndex = 1
                } else if (icsPropType === cbPropertyType.ptime) {
                    cbPropertyType.currentIndex = 2
                } else {
                    cbPropertyType.currentIndex = 3
                }
                cbPropertyType.ptype = icsPropType
                cbFilteringCriteria.selectedComparison = icsCriteria
                filterValueTF.text = icsValue
                //page.filterSelected()
                listViewFilters.currentIndex = index
                console.log(cbFilterComponent.currentIndex)
            }

            Label {
                anchors.centerIn: parent
                text: icsComponent + "." + icsProperty + " " +
                      icsCriteria + " " + icsValue
                color: Theme.secondaryColor
            }
        }
    }

    SilicaFlickable {
        anchors.fill: parent
        contentHeight: column.height

        PullDownMenu {
            MenuItem {
                text: qsTr("add")
                enabled: filterValueTF.text != ""
                onClicked: {
                    addFilter()
                    composeJson()
                    filterIcsFile()
                    eventsView.refresh()
                }
            }
            /*MenuItem {
                text: qsTr("modify current")
                enabled: (listViewFilters.currentIndex >= 0 || eventsView.visible) ? true : false
                onClicked: {
                    if (eventsView.visible) {
                        eventsView.visible = false
                    } else {
                        modifyFilter(listViewFilters.currentIndex)
                    }
                }
            } //*/
        }

        Icon {
            source: calendarOptions.isPassFilter?
                        "image://theme/icon-s-checkmark":
                        "image://theme/icon-s-blocked"
            visible: !calendarOptions.expanded
            y: calendarOptions.y + 0.5*(calendarOptions.height - height)
            x: Theme.horizontalPageMargin
            color: Theme.secondaryHighlightColor
        }

        Column {
            id: column
            width: parent.width
            spacing: 0//Theme.paddingSmall

            PageHeader {
                id: header
                title: qsTr("iCalendar filters")
            }

            Row {
                x: Theme.horizontalPageMargin
                spacing: Theme.paddingLarge
                width: parent.width - 2*x

                Label {
                    id: calendarLabel
                    text: qsTr("calendar")
                    color: Theme.secondaryHighlightColor
                }

                Label {
                    id: calendarName
                    text: ""
                    color: Theme.highlightColor
                    width: parent.width - x
                    wrapMode: Text.WrapAtWordBoundaryOrAnywhere
                }

            }

            ExpandingSection {
                id: calendarOptions
                title: qsTr("options")
                content.sourceComponent: Column {
                    width: page.width

                    Connections {
                        target: page
                        onRefresh: {
                            var ic
                            cbComponent.currentIndex = cbFilterComponent.currentIndex
                            ic = calendarComponents.getIndex(cbFilterComponent.value)
                            blockOrPass.checked = calendarComponents.get(ic).isPass
                            allOrAnyComponent.checked = calendarComponents.get(ic).limit > 0
                            //calendarOptions.isAnd = allOrAnyComponent.checked
                        }
                    }

                    Label {//SectionHeader {
                        text: qsTr("calendar options")
                        color: Theme.secondaryHighlightColor
                        x: Theme.horizontalPageMargin
                    }

                    TextSwitch {
                        id: reminderAdd
                        text: checked? qsTr("add a reminder for normal events"):
                                       qsTr("no reminders for normal events")
                        property bool selected: checked
                        onSelectedChanged: {
                            calendarOptions.pAddReminder = checked
                            if (checked) {
                                reminderNormal.focus = true
                            }
                        }
                    }

                    TextField {
                        id: reminderNormal
                        placeholderText: qsTr("remind NN min before the event, after if negative")
                        label: text*1.0 > 0? qsTr("remind %1 min before the event").arg(text) : qsTr("remind %1 min after the start").arg(-1.0*text)
                        inputMethodHints: Qt.ImhDigitsOnly
                        validator: IntValidator{}
                        visible: reminderAdd.checked
                        EnterKey.onClicked: focus = false
                        onFocusChanged: {
                            if (!focus && acceptableInput) {
                                calendarOptions.pReminder = text*1
                            }
                        }
                        onTextChanged: {
                            // pressing +/- changes the sign always
                            // changes needed only, if the sign is not the first character
                            if (text.indexOf("+", 1) > 0 ||
                                    text.indexOf("-", 1) > 0) {
                                var nbr, sign, strs, txt;

                                // the sign after the latest +/-
                                if (text.charAt(0) === "-") {
                                    sign = 1
                                    txt = text.substring(1)
                                } else {
                                    sign = -1
                                    if (text.charAt(0) === "+") {
                                        txt = text.substring(1)
                                    } else {
                                        txt = text
                                    }
                                }

                                if (txt.indexOf("+") > 0) {
                                    strs = txt.split("+")
                                } else {
                                    strs = txt.split("-")
                                }

                                if (strs.length >= 2) {
                                    txt = strs[0] + strs[1]
                                } else if (strs.length === 1) {
                                    txt = strs[0]
                                }
                                if (!isNaN(txt*1.0)) {
                                    _editor.text = sign*txt*1.0
                                } else {
                                    if (sign < 0) {
                                        _editor.text = "-"
                                    } else {
                                        _editor.text = ""
                                    }
                                }
                            }
                        }
                    }

                    TextSwitch {
                        id: reminderFullDayAdd
                        text: checked? qsTr("add a reminder for full day events"):
                                       qsTr("no reminders for full day events")
                        property bool selected: checked
                        onCheckedChanged: {
                            calendarOptions.pAddReminderFullDay = checked
                            if (checked) {
                                reminderFullDay.focus = true
                            }
                        }
                    }

                    TextField {
                        id: reminderFullDay
                        width: parent.width
                        placeholderText: qsTr("remind at hh:mm on the previous day, -hh:mm at the same day")
                        label: text.charAt(0) == "-" ? qsTr("remind at %1 at the event day").arg(text) : qsTr("remind at %1 at the previous day").arg(text)
                        validator: RegExpValidator {
                            regExp: /-?[0-2]?[0-9]:[0-5][0-9]/
                        }
                        visible: reminderFullDayAdd.checked
                        EnterKey.onClicked: focus = false
                        onFocusChanged: {
                            if (!focus && acceptableInput) {
                                calendarOptions.pReminderTime = text
                            } else {
                                text = calendarOptions.pReminderTime
                            }
                        }

                        property string time: text.charAt(0) == "-" ? text : text.substring(1)
                    }

                    //SectionHeader {
                    //    text: qsTr("options for component %1").arg(cbFilterComponent.value)
                    //}

                    ComboBox {
                        id: cbComponent
                        label: qsTr("options for component")
                        menu: ContextMenu {
                            Repeater {
                                //id: menuComponents
                                model: calendarComponents
                                MenuItem {
                                    text: icalComponent
                                    //onClicked: {
                                    //    cbComponent.value = text
                                    //}
                                }
                            }
                        }
                        //property int fcValue: -1
                        onCurrentIndexChanged: {
                            var i = calendarComponents.getIndex(value)
                            if (i >= 0 && i < calendarComponents.count) {
                                blockOrPass.checked = calendarComponents.get(i).isPass
                                if (calendarComponents.get(i).limit > 0) {
                                    allOrAnyComponent.checked = true
                                } else {
                                    allOrAnyComponent.checked = false
                                }
                            }
                        }
                    }

                    TextSwitch {
                        id: blockOrPass
                        text: checked? qsTr("components matching the filters will be passed through") :
                                       qsTr("components matching the filters will be left out")
                        onClicked: {
                            calendarOptions.isPassFilter = checked
                            calendarComponents.modifyAction(cbComponent.value, checked)
                        }
                    }

                    TextSwitch {
                        id: allOrAnyComponent
                        text: checked? qsTr("for the component to match the filter, all defined property filters have to match") :
                                       qsTr("for the component to match the filter, a single matching property is enough")
                        onClicked: {
                            var limit
                            if (checked) {
                                limit = 100
                            } else {
                                limit = 0
                            }
                            calendarComponents.modifyLimit(cbComponent.value, limit)
                        }
                    }
                }

                property bool pAddReminder: false
                property bool pAddReminderFullDay: false
                property int pReminder: 0
                property string pReminderTime: ""

                property bool isPassFilter: false
                //property bool isAnd: false
            }

            ListModel {
                id: calendarComponents
                ListElement {
                    icalComponent: "vevent"
                    //type: 1
                    isPass: false
                    limit: 0
                }
                ListElement {
                    icalComponent: "vtodo"
                    //type: 2
                    isPass: false
                    limit: 0
                }
                ListElement {
                    icalComponent: "vfreebusy"
                    //type: 3
                    isPass: false
                    limit: 0
                }

                function addComponent(cmp, passOrBlock, percent) {
                    var result;
                    if (getIndex(cmp) < 0) {
                        append({"icalComponent": cmp,
                                   "isPass": passOrBlock,
                                   "limit": percent});
                        result = 0;
                    } else {
                        console.log("component " + cmp + " exists, not added");
                        result = -1;
                    }
                    return result;
                }

                function modifyAction(cmp, passBlock) {
                    var i = 0;
                    if (passBlock === true || passBlock === false) {
                        i = getIndex(cmp);
                        if (i >= 0) {
                            set(i, {"isPass": passBlock})
                        } else {
                            console.log("component " + cmp +
                                        " not modified: unknown type")
                        }
                    } else {
                        console.log("component " + cmp +
                                    " not modified: bad parameters - true/false = "
                                    + passBlock)
                    }
                    return;
                }

                function modifyLimit(cmp, percent) {
                    var i = 0;
                    if (percent >= 0 && percent <= 100) {
                        i = getIndex(cmp);
                        if (i >= 0) {
                            set(i, {"limit": percent})
                        } else {
                            console.log("component " + cmp +
                                        " not modified: unknown type")
                        }
                    } else {
                        console.log("component " + cmp +
                                    " not modified: bad parameters - 0-100 = "
                                    + percent)
                    }
                    return;
                }

                function getIndex(cmp) {
                    var i=0, result = -1;
                    while (i < count) {
                        if (get(i).icalComponent === cmp) {
                            result = i;
                            i = count + 1;
                        }
                        i++;
                    }
                    console.log(cmp + ", " + i + ", " + count + ", " + result)
                    return result;
                }

                function getPassOrBlock(cmp) {
                    var i, result;
                    i = getIndex(cmp);
                    if (i >= 0 && i < count) {
                        result = get(i).isPass;
                    }

                    return result;
                }

                function getLimit(cmp) {
                    var i, result;
                    i = getIndex(cmp);
                    if (i >= 0 && i < count) {
                        result = get(i).limit;
                    }
                    return result;
                }

                //readonly property int fcOther: 0
                //readonly property int fcEvent: 1
                //readonly property int fcTodo: 2
                //readonly property int fcFreeBusy: 3
                //readonly property int fcUndefined: -1
            }

            ComboBox {
                id: cbFilterComponent
                label: qsTr("filters for component")
                menu: ContextMenu {
                    Repeater {
                        //id: menuComponents
                        model: calendarComponents
                        MenuItem {
                            text: icalComponent
                            onClicked: {
                                cbFilterComponent.currentIndex = index
                                cbFilterComponent.value = text
                                page.refresh()
                                //cbFilterComponent.fcValue = type
                            }
                        }
                    }
                }
                //onCurrentIndexChanged: {
                //    if (currentIndex == 0) {
                //        fcValue = fcOther
                //    } else if (currentIndex == 1){
                //        fcValue = fcEvent
                //    } else if (currentIndex == 2){
                //        fcValue = fcTodo
                //    } else if (currentIndex == 3){
                //        fcValue = fcFreeBusy
                //    } else {
                //        fcValue = fcUndefined
                //    }
                //}
                //property int fcValue: calendarComponents.fcEvent

            }

            ListModel {
                id: eventProperties
                // class / created / description / geo /
                // last-mod / location / organizer / priority /
                // seq / status / summary / transp /
                // url / recurid /dtend / duration /
                // attach / attendee / categories / comment /
                // contact / exdate / rstatus / related /
                // resources / rdate / x-prop / iana-prop
                ListElement {
                    prop: "categories"
                }
                ListElement {
                    prop: "class"
                }
                ListElement {
                    prop: "description"
                }
                ListElement {
                    prop: "dtstart"
                }
                ListElement {
                    prop: "priority"
                }

                function addProperty(prop) {
                    append({"prop": prop});
                }
            }

            ComboBox {
                id: cbFilterField
                label: qsTr("property")
                enabled: eventProperties.count > 0
                menu: ContextMenu {
                    //id: menuFilterFields
                    Repeater {
                        //id: menuProperties
                        model: eventProperties
                        MenuItem {
                            text: prop
                        }
                    }
                }
                onCurrentIndexChanged: {
                    if (value == "dtstart") {
                        cbPropertyType.currentIndex = cbPropertyType.ptime - 1
                        cbPropertyType.ptype = cbPropertyType.ptime - 1
                    }
                }
            }

            ComboBox {
                id: cbPropertyType
                label: qsTr("type of property")
                menu: ContextMenu {
                    MenuItem {
                        text: qsTr("string")
                        onClicked: {
                            cbPropertyType.ptype = cbPropertyType.pstring
                        }
                    }
                    MenuItem {
                        text: qsTr("date")
                        onClicked: {
                            cbPropertyType.ptype = cbPropertyType.pdate
                        }
                    }
                    //MenuItem {
                    //    text: qsTr("week day")
                    //    onClicked: {
                    //        cbPropertyType.ptype = cbPropertyType.pdate
                    //    }
                    //}
                    MenuItem {
                        text: qsTr("time")
                        onClicked: {
                            cbPropertyType.ptype = cbPropertyType.ptime
                        }
                    }
                    MenuItem {
                        text: qsTr("number")
                        onClicked: {
                            cbPropertyType.ptype = cbPropertyType.pnumber
                        }
                    }
                }

                property int ptype: pstring
                readonly property int pstring: 1
                readonly property int pdate: 2
                readonly property int ptime: 3
                readonly property int pnumber: 4

                function pTypeToString(typeNr) {
                    var result;
                    if (typeNr === pstring) {
                        result = "string";
                    } else if (typeNr === pdate) {
                        result = "date";
                    } else if (typeNr === ptime) {
                        result = "time";
                    } else if (typeNr === pnumber) {
                        result = "number";
                    }

                    return result;
                }
            }

            TextSwitch {
                id: allOrAnyValue
                text: checked? qsTr("all property filters have to match") :
                               qsTr("a single property match is enough")
            }

            ListModel {
                id: criteriaStrings
                ListElement {
                    description: qsTr("equal to")
                    comparison: "="
                }
                ListElement {
                    description: qsTr("not equal to")
                    comparison: "!="
                }
                ListElement {
                    description: qsTr("contains")
                    comparison: "s"
                }
                ListElement {
                    description: qsTr("doesn't contain")
                    comparison: "!s"
                }
            }

            ListModel {
                id: criteriaTime
                ListElement {
                    description: qsTr("equal to")
                    comparison: "="
                }
                ListElement {
                    description: qsTr("not equal to")
                    comparison: "!="
                }
                ListElement {
                    description: qsTr("earliest at")
                    comparison: ">="
                }
                ListElement {
                    description: qsTr("latest at")
                    comparison: "<="
                }
            }

            ListModel {
                id: criteriaNumber
                ListElement {
                    description: qsTr("equal to")
                    comparison: "="
                }
                ListElement {
                    description: qsTr("not equal to")
                    comparison: "!="
                }
                ListElement {
                    description: qsTr("larger than or equal to")
                    comparison: ">="
                }
                ListElement {
                    description: qsTr("smaller than or equal to")
                    comparison: "<="
                }
            }

            ComboBox {
                id: cbFilteringCriteria
                //anchors {
                    //top: cbFilterField.bottom
                    //topMargin: Theme.paddingSmall
                    //left: parent.left
                    //leftMargin: Theme.horizontalPageMargin
                //}
                //visible: !eventsView.visible
                enabled: cbPropertyType.ptype >= 0
                label: qsTr("criteria")
                menu: ContextMenu {
                    id: criteriaMenu3
                    Repeater {
                        model: cbPropertyType.ptype == cbPropertyType.pstring? criteriaStrings :
                                    (cbPropertyType.ptype == cbPropertyType.pnumber?
                                         criteriaNumber : criteriaTime)
                        MenuItem {
                            text: description
                            onClicked: {
                                cbFilteringCriteria.selectedComparison = comparison
                                console.log(cbFilteringCriteria.selectedComparison + ", " + description + ", " + comparison)
                            }
                        }
                    }
                }

                property string selectedComparison: "="
                property string compareNumber: ""
                property string compareString: ""
                property string compareTime: ""

                onCurrentIndexChanged: {
                    if (currentIndex >= 0) {
                        if (cbPropertyType.ptype == cbPropertyType.pnumber &&
                                currentIndex < criteriaNumber.count) {
                            compareNumber = criteriaNumber.get(currentIndex).comparison
                        } else if (cbPropertyType.ptype == cbPropertyType.pstring &&
                                currentIndex < criteriaStrings.count) {
                            compareString = criteriaStrings.get(currentIndex).comparison
                        } else if (cbPropertyType.ptype == cbPropertyType.ptime &&
                                currentIndex < criteriaTime.count) {
                            compareTime =  criteriaTime.get(currentIndex).comparison
                        }
                    }
                }
            }

            TextField {
                id: filterValueTF
                label: qsTr("value")
                placeholderText: qsTr("filtering value")
                width: parent.width
                EnterKey.onClicked: focus = false
            }

            SectionHeader{
                id: shFilters
                //visible: !eventsView.visible
                text: qsTr("filters")
            }

            SilicaListView {
                id: listViewFilters
                x: Theme.horizontalPageMargin
                width: parent.width - 2*x
                height: count > 4 ? 4*Theme.itemSizeSmall : count*Theme.itemSizeSmall
                spacing: 0// Theme.paddingSmall
                clip: false//

                model: filterModel
                delegate: filterDelegate

                highlight: Rectangle {
                    color: Theme.highlightBackgroundColor
                    height: listViewFilters.currentItem.height
                    width: listViewFilters.width
                    radius: Theme.paddingMedium
                    border.color: Theme.highlightColor
                    border.width: 2
                    opacity: Theme.highlightBackgroundOpacity
                }

                highlightFollowsCurrentItem: true
            }

            SectionHeader{
                text: qsTr("filters file")
            }

            TextArea {
                id: viewFiltersFile
                width: parent.width
                height: Theme.fontSizeSmall*16
                font.pixelSize: Theme.fontSizeMedium
                readOnly: true
                onClicked: {
                    if (mika === 0) {
                        text = JSON.stringify(jsonFilter)
                    } else if (mika === 1) {
                        text = icsModified
                    } else {
                        text = icsFile
                        mika = -1
                    }

                    mika++
                }

                property int mika: 0
            }

            SectionHeader{
                //id: shEvents
                text: qsTr("events")
                //visible: eventsView.visible
            }

            IcalEventView {
                id: eventsView
                width: parent.width
                height: Theme.fontSizeMedium*6//parent.height - y
                //visible: false
                icsOriginal: icsFile
            }

            VerticalScrollDecorator {}
        }

    }

    /*
    function qqaddEvent(calNr, event) {
        var date, qq, ms, ifMatches = false//, isIncluded = true//, min=60*1000
        var evItem = {"year": "", "day": "", "clock": "", "type": "", "location": "",
            "description": "", "include": ifMatches }//, "showDesc": false }
        var time = event.DTSTART, title = decodeURI(event.CATEGORIES),
            loc = decodeURI(event.LOCATION), desc = decodeURI(event.DESCRIPTION)
        if (title.length < 1)
            title = event.SUMMARY
        title = decodeURI(title)

        // timeZone should be checked at the event time, not when the function is called
        ms = Ical.icsTimeToMs(time)  // in UTC 0

        date = new Date(ms)

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

        qq = DataB.readSetting(calNr, "filter")
        if (qq !== undefined){
            ifMatches = qq
        } else
            console.log(" not defined !!")

        evItem.include = Utils.filterEvent(event, calId, DataB.filtersTable, ifMatches)

        console.log(" filter " + ifMatches + " # " + evItem.include)

        eventsView.append(evItem)

        return
    }

    function qqaddFilter() {
        ///*   icsFilters = id INTEGER, calId INTEGER, item TEXT, field TEXT, value TEXT, srch TEXT, filter INTEGER
        //-calId: id of the calendar that is filtered
        //-item: which elements to filter vevent, vtodo, vjournal
        //-field: which field of the item is used
        //-value: text to be searched in the field
        //-srch: search method: "starts" - startsWith, "STARTS" - case sensitive, "ends" - endsWith,
        //    "ENDS", "index" - indexOf, "INDEX" - case sentive,
        //    "equal" - ==, "larger" - >, "smaller" - <
        //-filter: 0 - leave out, 1 - include // defined in calendar settings
        ///
        var itemType = "VEVENT", func, filterId//, inOrOut
        if (caseSensitivityTS.checked) {
            func = cbFilteringCriteria.value.toLocaleUpperCase()
        } else
            func = cbFilteringCriteria.value

        //in or out is defined on the calendar settings
        //if (filterOutTS.checked)
        //    inOrOut = 0 // 0 - leave out, 1 - include
        //else
        //    inOrOut = 1

        filterId = DataB.addFilter(calId, itemType, cbFilterField.value, filterValueTF.text, func)
        if (filterId >= 0)
            showFilter(filterId, calId, itemType, cbFilterField.value, filterValueTF.text, func)

        return
    }

    //*/

    // adds propertydata to the list
    function addFilter(filterNr) { // if filterNr >= 0, modifies a filter
        var action, propMatches, valMatches, vcomponent;

        if (allOrAnyValue.checked) {
            valMatches = 100;
        } else {
            valMatches = 0.0;
        }

        //vcomponent = icsComponentNr(cbFilterComponent.fcValue);
        vcomponent = cbFilterComponent.value;
        console.log("vcomponent " + vcomponent);
        //if (cbFilterComponent.fcValue == calendarComponents.fcEvent) {
        //    vcomponent = "vevent";
        //} else if (cbFilterComponent.fcValue == calendarComponents.fcTodo) {
        //    vcomponent = "vtodo";
        //} else if (cbFilterComponent.fcValue == calendarComponents.fcFreeBusy) {
        //    vcomponent = "vfreebusy";
        //} else {
        //    return;
        //}
        //if (typeof vcomponent === typeof 1 || vcomponent === "") {
        //    return;
        //}

        if (filterNr >= 0) {
            filterModel.modifyFilter(filterNr, vcomponent, //action, propMatches,
                                  cbFilterField.value, cbPropertyType.ptype,
                                  valMatches, cbFilteringCriteria.selectedComparison,
                                  filterValueTF.text);
        } else {
            filterModel.addFilter(vcomponent, //action, propMatches,
                                  cbFilterField.value, cbPropertyType.ptype,
                                  valMatches, cbFilteringCriteria.selectedComparison,
                                  filterValueTF.text);
        }

        return;
    }

    function composeJson() {
        var filterJson = "", ic, n, nc, prevComp, prevProp, prevVal, propType;
        var cals, calN, cmponent, crtr, flters, ifl, ip, prop, prperties, vals;
        calN = {"label": "", "filters": []};
        cmponent = {"component": "", "properties": []};
        prop = {"property": "", "values": []};
        crtr = {"criteria": "", "value": ""};

        filterJson += '{ "calendars": [\n';
        if (!jsonFilter) {
            cals = [];
        } else {
            cals = jsonFilter.calendars;
        }

        if (calendarName.text != "") {
            filterJson += '  { "label": "';
            filterJson += calendarName.text;
            filterJson += '",\n';
            nc = cals.length;
            n = 0;
            while (n < nc) {
                console.log(cals[n].label + " - " + calendarName.text.toLowerCase().match(cals[n].label.toLowerCase()));
                if (cals[n].label > "" && calendarName.text.toLowerCase().match(cals[n].label.toLowerCase())) {
                    nc = n;
                    n = cals.length;
                }
                n++;
            }
        } else {
            return;
        }

        calN["label"] = calendarName.text;

        if (calendarOptions.pAddReminder) {
            //filterJson += '    "reminder": ' + calendarOptions.pReminder + ',\n';
            calN["reminder"] = calendarOptions.pReminder;
        }
        if (calendarOptions.pAddReminderFullDay) {
            //filterJson += '    "dayreminder": ' + calendarOptions.pReminderTime + ',\n';
            calN["dayreminder"] = calendarOptions.pReminderTime;
        }

        filterJson += '    "filters": [\n';
        ic = 0;
        while (ic < filterModel.count) {
            if (filterModel.get(ic).icsComponent != prevComp) {
                if (filterJson.charAt(filterJson.length - 1) === '}') {
                    filterJson += ']\n'; // values-list
                    filterJson += '      }]\n'; // properties-list
                    filterJson += '    },\n'; // component-item
                }

                prevComp = filterModel.get(ic).icsComponent;
                prevProp = undefined;
                filterJson += '    { "component": "' + prevComp + '",\n';
                if (calendarComponents.getPassOrBlock(prevComp) == isAccept) {//if (filterModel.get(ic).icsReject == isAccept) {
                    filterJson += '      "action": "accept",\n';
                } else {
                    filterJson += '      "action": "reject",\n';
                }
                //filterJson += '      "propMatches": ' + filterModel.get(ic).icsPrpMatches + ',\n';
                filterJson += '      "propMatches": ' + calendarComponents.getLimit(prevComp) + ',\n';
                filterJson += '      "properties": [\n';
            }
            if (filterModel.get(ic).icsProperty != prevProp) {
                if (filterJson.charAt(filterJson.length - 1) === '}') {
                    filterJson += ']\n';
                    filterJson += '      },';
                }
                prevProp = filterModel.get(ic).icsProperty;
                filterJson += '      { "property": "' + prevProp + '",\n';
                filterJson += '        "type": "' + cbPropertyType.pTypeToString(filterModel.get(ic).icsPropType) + '",\n';
                filterJson += '        "valueMatches": ' + filterModel.get(ic).icsValMatches + ',\n';
                filterJson += '        "values": [\n';
            }
            if (filterJson.charAt(filterJson.length-1) === '}') {
                filterJson += ',\n';
            }
            filterJson += '        { "criteria": "' + filterModel.get(ic).icsCriteria + '",\n';
            filterJson += '          "value": "' + filterModel.get(ic).icsValue + '"\n';
            filterJson += '        }';
            ic++;
        }

        flters = [];
        ifl = 0;
        ic = 0;
        while (ic < filterModel.count) {
            //{"icsComponent", "icsProperty", "icsPropType",
            //"icsValMatches", "icsCriteria", "icsValue"}
            ifl = isComponentIncluded(flters, filterModel.get(ic).icsComponent);
            console.log(">> " + filterModel.get(ic).icsComponent + ", nr " + ifl)
            if (ifl >= 0) { // rewrite the component
                cmponent = flters[ifl];
                prperties = cmponent.properties;
            } else { // new component
                cmponent["component"] = filterModel.get(ic).icsComponent;
                prperties = [];
            }
            if (calendarComponents.getPassOrBlock(cmponent["component"]) === isAccept) {
                cmponent["action"] = "accept";
            } else {
                cmponent["action"] = "reject";
            }
            cmponent["propMatches"] = calendarComponents.getLimit(cmponent["component"]);

            console.log(">> " + filterModel.get(ic).icsProperty + ", nr " + ifl);
            ip = isPropertyIncluded(prperties, filterModel.get(ic).icsProperty);
            if (ip >= 0) { // rewrite filters for the property
                prop = prperties[ip];
                vals = prop.values;
            } else { // new property
                prop["property"] = filterModel.get(ic).icsProperty;
                vals = [];
            }

            prop["type"] = cbPropertyType.pTypeToString(filterModel.get(ic).icsPropType);
            prop["valueMatches"] = filterModel.get(ic).icsValMatches;

            crtr["criteria"] = filterModel.get(ic).icsCriteria;
            crtr["value"] = filterModel.get(ic).icsValue;
            vals.push(crtr);

            prop["values"] = vals;

            if (ip >= 0) {
                cmponent["properties"][ip] = prop;
            } else {
                cmponent["properties"].push(prop);
            }

            if (ifl >= 0) {
                flters[ifl] = cmponent;
            } else {
                flters.push(cmponent);
                ifl = flters.length - 1;
            }
            ic++;
        }

        calN["filters"] = flters;

        if (nc < cals.length) {
            cals[nc] = calN;
        } else {
            cals.push(calN);
        }

        jsonFilter.calendars = cals;
        viewFiltersFile.text = JSON.stringify(jsonFilter);
        //viewFiltersFile.text = filterJson;
        //console.log(filterJson);
        //jsonFilter = JSON.parse(filterJson);
        return;
    }

    /*
    function icsComponentNr(input) {
        var result;
        if (typeof input === typeof 3) {
            if (input === calendarComponents.fcEvent) {
                result = "vevent";
            } else if (input === calendarComponents.fcTodo) {
                result = "vtodo";
            } else if (input === calendarComponents.fcFreeBusy) {
                result = "vfreebusy";
            } else {
                result = "";
            }
        } else if (typeof input === typeof "") {
            if (input.toLowerCase() === "vevent") {
                result = calendarComponents.fcEvent;
            } else if (input.toLowerCase() === "vtodo") {
                result = calendarComponents.fcTodo;
            } else if (input.toLowerCase() === "vfreebusy") {
                result = calendarComponents.fcFreeBusy;
            } else {
                result = calendarComponents.fcOther;
            }
        }
        return result;
    }

    function qqcomposeFilter() {
        var setCalendar = false, setComponent = false, setProperty = false;

        if (filterParameters.reminderAdvance*1.0 != reminderNormal.text*1.0) {
            setCalendar = true;
        }

        if (setCalendar) {
            var alarmNormal, alarmFullDay;

            if (reminderAdd.checked) {
                alarmNormal = reminderNormal.text;
            } else {
                alarmNormal = "";
            }
            if (reminderFullDay.checked) {
                alarmFullDay = reminderFullDay.text;
            } else {
                alarmFullDay = "";
            }

            //icsFilter.createFilterCalendar(label, idProperty, idValue, reminder, reminderFullDay);
            icsFilter.createFilterCalendar(calendarName.text,
                                "", "", alarmNormal, alarmFullDay);
            filterParameters.reminderAdvance = reminderNormal.text*1.0;
        }

        if (cbFilterComponent.value != filterParameters.vcomponent ||
                blockOrPass.checked != filterParameters.passBlock ||
                allOrAnyComponent.checked != filterParameters.andOrComponent) {
            var action, nrMatches;
            if (blockOrPass.checked) {
                action = -1;
            } else {
                action = 1;
            }
            if (allOrAnyComponent.checked) {
                nrMatches = 1.0;
            } else {
                nrMatches = 0.0;
            }

            //icsFilter.createFilterComponent(component, action, nrMatches);
            icsFilter.createFilterComponent(cbFilterComponent.value, action, nrMatches);
            filterParameters.vcomponent = cbFilterComponent.value;
            filterParameters.passBlock = blockOrPass.checked;
            filterParameters.andOrComponent = allOrAnyComponent.checked;
        }

        if (filterParameters.andOrProperty != allOrAnyValue.checked ||
                filterParameters.cProperty != cbFilterField.value ||
                filterParameters.ptype != cbPropertyType.value) {
            var percentMatches;
            if (allOrAnyValue.checked) {
                percentMatches = 1.0;
            } else {
                percentMatches = 0.0;
            }
            filterParameters.andOrProperty =  allOrAnyValue;
            filterParameters.cProperty = cbFilterField.value;
            filterParameters.ptype = cbPropertyType.value;

            //icsFilter.createFilterProperty(component, property, type, nrMatches);
            icsFilter.createFilterProperty(cbFilterComponent.value, cbFilterField.value,
                                           cbPropertyType.value, percentMatches);
        }

        //icsFilter.createFilterValue("append", component, property, criteria, value);
        icsFilter.createFilterValue("append", cbFilterComponent.value, cbFilterField.value,
                                    cbFilteringCriteria.value, filterValueTF.text);

        icsFilter.storeFilter();
    }

    function qqfilterEvents(icsEvents) { // events are included, if no filter matches the event
        var i=0, N=icsEvents.count//N=icsEvents.length
        var filterType = DataB.readSetting(calId, "filter"), readIn = true

        console.log("icsevents " + N)

        while (i < N) {
            addEvent(calId, icsEvents.items[i])//icsJson.vEvents.items[i])
            i++
        }

        return
    }

    function modifyFilter(id) {
        var field, value, filter

        return
    }
    // */

    function filterIcsFile() {
        icsModified = icsFilter.filterIcs(calendarLbl, icsFile,
                                          JSON.stringify(jsonFilter));
        console.log("muokattu :" + icsModified);
        eventsView.icsModified = icsModified;
        //var defInclude

        //eventsView.model.clear()
        //if (DataB.findSetting(calId, "filter") === 0)
        //    defInclude = false
        //else
        //    defInclude = true

        //console.log("ical " + DataB.findCalendarData(calId).name + " length " + icsFile.length)
        //Ical.filterFile(calId, icsFile, defInclude, DataB.filtersTable,
        //                function(event) {
        //                    //eventsView.append(event)
        //                    return
        //                } )

        return;
    }

    function isComponentIncluded(filters, comp) {
        var i, result;
        result = -1;
        i = 0;
        while (i < filters.length) {
            if (filters[i].component.toLowerCase() === comp.toLowerCase()) {
                result = i;
                i = filters.length;
            }
            i++;
        }
        return result;
    }

    function isPropertyIncluded(propertyList, prName) {
        var i, result = "";
        result = -1;
        i = 0;
        while (i < propertyList.length) {
            if (propertyList[i].property.toLowerCase() === prName.toLowerCase()){
                result = i;
            }
            i++;
        }
        return result;
    }

    function readCalendarFilters() {
        var filtersJson;
        filtersJson = icsFilter.readFiltersFile();
    }

    /*
    function qqReadCalendarFilters(calId) {
        var i = 0, N = DataB.filtersTable.length
        console.log(" -- length " + N)
        while (i < N) {
            if (DataB.filtersTable[i].calId == calId) {
                showFilter(DataB.filtersTable[i].id, calId,
                           DataB.filtersTable[i].item, DataB.filtersTable[i].field,
                           DataB.filtersTable[i].value, DataB.filtersTable[i].srch)
            }

            console.log(" << " + DataB.filtersTable[i].calId + " == " + calId + ", " +
                        DataB.filtersTable[i].field)

            i++
        }
        console.log("filters " + N + ".")

        return
    }
    // */

    /*
    function qqrefreshEvents() {
        // clears filtering tests
        //console.log(JSON.stringify(Ical.icsJson))
        eventsView.model.clear()
        console.log("  == " + Ical.icsJson.VCALENDAR.vEvents.count )
        //filterEvents(Ical.icsJson.vEvents.items)
        filterEvents(Ical.icsJson.VCALENDAR.vEvents)

        return
    }
    //*/

    function showFilter(filterId, calId, itemType, field, value, srch) {
        filtersListModel.append( { "id": filterId, "calendar": calId,
                                    "calItem": itemType, //"checkCase": checkCase,
                                    "field": field, "value": value,
                                    "srch": srch } )

        return
    }

}
