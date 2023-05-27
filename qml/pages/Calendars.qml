import QtQuick 2.0
import Sailfish.Silica 1.0
import QtQuick.LocalStorage 2.0
import Nemo.Notifications 1.0
import "../scripts/ical.js" as Ical
import "../scripts/dbase.js" as DataB
import "../scripts/utils.js" as Utils

Page {
    id: page

    // The effective value will be restricted by ApplicationWindow.allowedOrientations
    allowedOrientations: Orientation.All
    Component.onCompleted: {
        currentCalendars()
        calendarListView.currentIndex = -1
    }

    Component.onDestruction: {
        closing()
    }


    signal closing
    property bool newCalendar: true
    property int currentCalendar: -1

    Notification {
        id: note
    }

    Component {
        id: calendarListDelegate
        ListItem {
            id: calendarItem
            width: page.width - 2*Theme.horizontalPageMargin
            //highlighted: false //highlightedColor: "transparent"
            propagateComposedEvents: true
            _backgroundColor: "transparent" //does not flash - listviews highlight is enough
            onClicked: {
                currentCalendar = calendarListView.indexAt(mouseX, y + mouseY)
                calendarListView.currentIndex = currentCalendar
                //valittu = juomaLista.indexAt(mouseX,y+mouseY)
                mouse.accepted = false
                nameField.text = calendarListModel.get(currentCalendar).calName
                addressField.text = calendarListModel.get(currentCalendar).calUrl
                filterBehaviour.checked = calendarListModel.get(currentCalendar).defMode
                //console.log("painettu " + currentCalendar + " - " + calendarListView.currentIndex)
            }

            onPressAndHold: {
                currentCalendar = calendarListView.indexAt(mouseX, y + mouseY)
                //console.log("paa-inettu " + currentCalendar + " - " + calendarListView.currentIndex)
                calendarListView.currentIndex = currentCalendar
                mouse.accepted = false
                subscribeItem.text = calendarListModel.get(currentCalendar).update?
                            qsTr("unsubscribe") : qsTr("subscribe")
            }

            menu: ContextMenu {
                MenuItem {
                    id: subscribeItem
                    text: qsTr("subscribe")
                    onClicked: {
                        changeSubscribtion(currentCalendar)
                    }
                }

                MenuItem {
                    text: qsTr("delete")
                    onClicked: {
                        calendarListView.currentItem.remorseAction(qsTr("deleting"), function () {
                            console.log("Deleted calendar " + calendarListModel.get(calendarListView.currentIndex).calId +
                                        " " + calendarListModel.get(calendarListView.currentIndex).calName)
                            DataB.removeCalendar(calendarListModel.get(calendarListView.currentIndex).calId)
                            calendarListModel.remove(calendarListView.currentIndex)
                        })

                    }
                }

            }

            Label {
                text: calName
                width: parent.width //Theme.fontSizeMedium*7 //ExtraSmall*8
                truncationMode: TruncationMode.Fade
                color: calendarItem.highlighted? Theme.highlightColor : Theme.secondaryColor
                horizontalAlignment: Text.AlignHCenter
                topPadding: Theme.paddingMedium
            }

        } //listitem
    } //rivityyppi

    ListModel {
        id: calendarListModel
        ListElement {
            calId: 0 // id
            calName: "" // name
            calUrl: "" // url
            update: true //automatic update?
            defMode: true // are events included if they don't match any filters?
        }
    }

    SilicaFlickable{
        anchors.fill: parent
        contentHeight: column.height

        PullDownMenu {
            MenuItem {
                text: qsTr("overwrite plugin setup")
                onClicked: {
                    writeIcalPlugin()
                }
            }

            MenuItem{
                text: qsTr("add %1").arg(nameField.text)
                onClicked: {
                    addCalendar()
                    clearFields()
                }
                enabled: (nameField.text != "" && addressField.text != "")
            }

            MenuItem{
                text: qsTr("modify %1").arg(nameField.text)
                onClicked: {
                    var cal, listId, name, adr, inOut, filterMode
                    cal = calendarListModel.get(calendarListView.currentIndex).calId
                    listId = calendarListView.currentIndex
                    name = nameField.text
                    adr = addressField.text
                    inOut = filterBehaviour.checked
                    filterMode = filterBehaviour.checked
                    calendarListView.currentItem.remorseAction(qsTr("modifying"), function () {
                        //console.log(" modify " + calendarListView.currentIndex)
                        modifyCalendar(listId, cal, name, adr, inOut, filterMode)
                        clearFields()
                    })
                    //modifyCalendar(calId)
                }
                enabled: (nameField.text != "" && addressField.text != ""
                          && calendarListView.currentIndex >= 0)
            }

        }

        Column {
            id: column
            width: parent.width

            PageHeader {
                title: qsTr("Calendars")
            }

            Row { // calendar
                spacing: Theme.paddingSmall
                width: parent.width

                IconButton {
                    id: clearNameField
                    icon.source: "image://theme/icon-m-clear?" +
                                 (pressed ? Theme.highlightColor : Theme.primaryColor)
                    onClicked: {
                        nameField.text = ""
                    }
                }

                TextField {
                    id: nameField
                    label: qsTr("calendar name")
                    placeholderText: label
                    text: ""
                    width: parent.width - x
                    EnterKey.iconSource: "image://theme/icon-m-enter-next"
                    EnterKey.onClicked: {
                        addressField.focus = true
                    }
                }

            }

            Row { // address
                spacing: Theme.paddingSmall
                width: parent.width

                IconButton {
                    id: clearAddressField
                    icon.source: "image://theme/icon-m-clear?" +
                                 (pressed ? Theme.highlightColor : Theme.primaryColor)
                    onClicked: {
                        addressField.text = ""
                    }
                }

                TextField {
                    id: addressField
                    label: qsTr("address")
                    placeholderText: label
                    text: ""
                    width: parent.width - x
                    EnterKey.iconSource: "image://theme/icon-m-enter-next"
                    EnterKey.onClicked: addressField.focus = false
                }

            }

            Label {
                text: "https://haagankarhut.nimenhuuto.com/calendar/ical?auth[user_id]=284538&auth[ver]=02&auth[signature]=71b4f7c43381a8146f954d03d8498af910a9aa93"
                MouseArea {
                    anchors.fill: parent
                    onClicked: {
                        Clipboard.text = parent.text
                    }
                }
            }

            TextSwitch {
                id: filterBehaviour
                text: qsTr("filtering type")
            }

            Label {
                text: filterBehaviour.checked ?
                          qsTr("all events are excluded by default - use filters to add events") :
                          qsTr("all events are included by default - use filters to block events")
                x: filterBehaviour.x + Theme.horizontalPageMargin
                width: parent.width - x
                color: Theme.highlightColor
                wrapMode: Text.WordWrap
            }

            Separator {
                horizontalAlignment: Qt.AlignHCenter
                color: Theme.secondaryHighlightColor
            }

            Button {
                text: "osoite"
                onClicked: {
                    Clipboard.text = "https://haagankarhut.nimenhuuto.com/calendar/ical?auth[user_id]=284538&auth[ver]=02&auth[signature]=71b4f7c43381a8146f954d03d8498af910a9aa93"
                    addressField.text = "https://haagankarhut.nimenhuuto.com/calendar/ical?auth[user_id]=284538&auth[ver]=02&auth[signature]=71b4f7c43381a8146f954d03d8498af910a9aa93"
                }
            }

            Separator {
                horizontalAlignment: Qt.AlignHCenter
                color: Theme.secondaryHighlightColor
            }

            SilicaListView {
                id: calendarListView
                model: calendarListModel
                delegate: calendarListDelegate
                highlight: Rectangle {
                    color: Theme.highlightBackgroundColor
                    height: calendarListView.currentIndex >= 0 ?
                                calendarListView.currentItem.height : Theme.fontSizeMedium
                    width: calendarListView.width
                    radius: Theme.paddingMedium
                    border.color: Theme.highlightColor
                    border.width: 2
                    opacity: Theme.highlightBackgroundOpacity
                }

                highlightFollowsCurrentItem: true
                width: parent.width
                height: page.height - y
                x: Theme.horizontalPageMargin
                clip: true

                VerticalScrollDecorator {}
            }

        }

    }

    function addCalendar() {
        if (nameField.text == "" || addressField.text == "") {
            errorMessage(qsTr("calendar not added."), qsTr("Calendar name or address empty."))
            return
        }

        if (!checkName(nameField.text))
            return

        if (!checkAddress(addressField.text))
            return

        DataB.addCalendar(nameField.text, addressField.text)
        currentCalendars()
        calendarListView.currentIndex = calendarListView.count - 1

        return
    }

    function changeSubscribtion(index) {
        var calId = calendarListModel.get(index).calId, i = -2, value
        console.log("" + index + " " + calendarListModel.get(index).calName)
        calendarListModel.get(index).update = !calendarListModel.get(index).update
        if (calendarListModel.get(index).update) {
            value = 0 // automatic / manual - selection not possible yet (if ever)
        } else {
            value = 2 // isn't visible on Selector-page
        }

        i = DataB.findSetting(calId, "update")
        if (i >= 0) { // modify
            DataB.modifySetting(calId, "update", value)

        } else {
            DataB.addSetting(calId, "update", value)
        }

        return
    }

    function checkAddress(url) {
        var ok = true, name = "", id = DataB.findCalendarUrl(url)

        if ( id >= 0) {
            name = DataB.icsTable[id].name
            var msg = qsTr("%2 already linked to \n %1").arg(url).arg(name)
            var dialog = pageStack.push( Qt.resolvedUrl("AcceptOrReject.qml"),
                                        {"title": qsTr("Duplicate url?"), "desc": msg })
            dialog.rejected.connect(function () {
                ok = false
            })
        }

        console.log("tulos = " + ok)

        return ok
    }

    function checkName(name) {
        var ok = true

        if (DataB.findCalendarName(name) >= 0) {
            var msg = qsTr("Calendar '%1' exists already. Do you want to create a new calendar using the same name?").arg(name)
            var dialog = pageStack.push( Qt.resolvedUrl("AcceptOrReject.qml"),
                                        {"title": qsTr("Duplicate name?"), "desc": msg })
            dialog.rejected.connect(function () {
                ok = false
            })
        }

        console.log("tulos = " + ok)

        return ok
    }

    function clearFields() {
        nameField.text = ""
        addressField.text = ""
        calendarListView.currentIndex = -1
        return
    }

    function currentCalendars() {
        var i = 0, N = DataB.icsTable.length, subscribe
        console.log("N " + N)
        calendarListModel.clear()
        while (i < N) {
            if (DataB.readSetting(DataB.icsTable[i].id, "update") > 0)
                subscribe = false
            else
                subscribe = true
            calendarListModel.append({"calId": DataB.icsTable[i].id,
                                     "calName": DataB.icsTable[i].name,
                                     "calUrl": DataB.icsTable[i].address,
                                     "update": subscribe })
            i++
        }

        return
    }

    function errorMessage(msg1, msg2) {
        note.previewSummary = msg1
        note.previewBody = msg2
        note.publish()
        console.log(msg1 + " " + msg2)
        return
    }

    function modifyCalendar(listId, calId, newName, newAddress, inOut, subscribe) {
        var msg1, msg2, defMode
        if (newName == "" || newAddress == "") {
            errorMessage( qsTr("Calendar not modified."),
                         qsTr("Calendar name or address empty.") )
            return
        }
        if (inOut) {
            defMode = 1
        } else {
            defMode = 0
        }

        DataB.modifyCalendar(calId, newName, newAddress)
        DataB.modifySetting(calId, "filter", defMode)
        DataB.modifySetting(calId, "update", subscribe)

        calendarListModel.set(listId, {
                                  "calName": newName,
                                  "calUrl": newAddress,
                                  "update": subscribe,
                                  "defMode": inOut
                              } )
        //nameField.text = calendarListModel.get(i).calName
        //addressField.text = calendarListModel.get(i).calUrl

        return
    }

    function writeIcalPlugin(){
        // subscriptions.xml: start+ (profileStart+ url+ profileMid+ name+ profileEnd)* + end
        //var file = "file:///home/nemo/.cache/msync/sync/subscriptions.xml"
        var file = "file:///home/nemo/.local/share/harbour-icals/subscriptions.xml"
        var fileContents = '<profile name="subscriptions" type="sync">\n' +
                    '  <key name="destinationtype" value="online"/>\n' +
                    '  <key name="enabled" value="true"/>\n' +
                    '  <key name="hidden" value="false"/>\n' +
                    '  <key name="use_accounts" value="false"/>\n'
        var profileStart = '  <profile type="client" name="webcal">\n    <key value="'
        var profileMid = '" name="remoteCalendar"/>\n    <key value="'
        var profileEnd = '" name="label"/>\n    <key value="true" name="allowRedirect" />\n  </profile>\n'
        var end = '  <schedule enabled="true" interval="1440" />\n</profile>'
        var i = 0, stat, subscribed

        while (i < DataB.icsTable.length){
            if (DataB.readSetting(DataB.icsTable.id, "update") == 0) {
                fileContents += profileStart
                fileContents += DataB.icsTable[i].address
                fileContents += profileMid
                fileContents += DataB.icsTable[i].name
                fileContents += profileEnd
            }

            i++
        }

        fileContents += end

        //console.log("=\n=\n subscriptions.xml: \n" + fileContents + "=\n=\n ")

        stat = Utils.fileWrite(file, fileContents)

        //console.log("write status " + stat)

        return
    }

}
