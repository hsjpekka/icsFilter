import QtQuick 2.0
import Sailfish.Silica 1.0
import "../scripts/ical.js" as Ical

Page {
    id: page
    allowedOrientations: Orientation.All

    property alias address: addressLabel.text
    property alias calendar: pageTitle.title
    property string original: ""
    property string filtered: ""
    property bool icsOrJson: true
    property bool isFiltered: false

    function exportFile() {
        var file = "", i = 0, N = 0
        if (icsOrJson) {
            while (i < icsRivit.count) {
                file += icsRivit.get(i).line
                i++
            }
        } else {
            while (i < jsonRivit.count) {
                file += jsonRivit.get(i).line
                i++
            }
        }
        Qt.openUrlExternally(file)

        return
    }

    function showFile(file) {
        if (icsOrJson)
            showIcsFile(file)
        else
            showJsonLines(file)

        return
    }

    // shows ics-file in listView
    function showIcsFile(icsFile) {
        var i = 0
        var icsLines = []
        if (icsRivit.count > 0)
            icsRivit.clear()

        icsLines = icsFile.split("\n");

        while (i < icsLines.length) {
            icsRivit.append({ "lineNumber": i + ":",
                                "line": icsLines[i]
                            })
            i++
        }

        return
    }

    // shows json-file in listView
    function showJsonLines(file) {
        var i = 0, jsonLines = [], icsLines = []

        icsLines = file.split("\r\n");
        if (icsLines.length < 2)
            icsLines = file.split("\n");

        Ical.unFoldLines(icsLines);

        Ical.removeEmptyLines(icsLines);

        jsonLines = Ical.compose(icsLines)

        if (jsonRivit.count > 0)
            jsonRivit.clear()

        console.log(" -- jsonRivit.count = " + jsonRivit.count)
        while (i < jsonLines.length) {
            jsonRivit.append({ "lineNumber": i + ":",
                                 "line": jsonLines[i]
                             })
            i++
        }
        console.log(" -- i = " + i)

        return
    }

    Component {
        id: lineView

        ListItem {
            id: riviNaytto
            width: icsNaytto.width
            height: txtLine.contentHeight + 2*txtLine.anchors.topMargin
            onClicked: {
                //rivi = icsNaytto.indexAt(mouseX, y + mouseY)
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

    SilicaFlickable {
        anchors.fill: parent
        contentHeight: column.height

        PullDownMenu {
            MenuItem {
                text: icsOrJson? qsTr("show JSON") : qsTr("show ics")
                onClicked: {
                    icsOrJson = !icsOrJson
                    if (isFiltered)
                        showFile(filtered)
                    else
                        showFile(original)
                }
            }
            MenuItem {
                text: isFiltered? qsTr("change to original") : qsTr("change to filtered")
                onClicked: {
                    isFiltered = !isFiltered
                    if (isFiltered)
                        showFile(filtered)
                    else
                        showFile(original)
                }
            }
            MenuItem {
                text: qsTr("export file")
                onClicked: {
                    exportFile()
                }
            }
        }

        Column {
            id: column
            width: parent.width

            PageHeader {
                id: pageTitle
                title: "Ics-file" //calendar name
            }

            Label {
                id: addressLabel
                text: "address"
                width: parent.width
                color: Theme.secondaryHighlightColor
                x: Theme.horizontalPageMargin
                wrapMode: Text.WrapAtWordBoundaryOrAnywhere
            }

            SectionHeader {
                text: icsOrJson? "ics " + icsNaytto.count : "json " + jsonNaytto.count
            }

            SilicaListView{
                id: icsNaytto
                width: parent.width
                height: page.height - y
                clip: true
                visible: icsOrJson

                model: ListModel{
                    id: icsRivit
                }
                delegate: lineView
            }

            SilicaListView{
                id: jsonNaytto
                width: parent.width
                height: page.height - y
                clip: true
                visible: !icsOrJson

                model: ListModel{
                    id: jsonRivit
                }
                delegate: lineView
            }

        } //column
    } //flickable

    Component.onCompleted: {
        showFile(original)

    }
}
