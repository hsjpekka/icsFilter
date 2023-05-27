import QtQuick 2.0
import Sailfish.Silica 1.0

ListItem {
    id: eventsListItem
    //width: parent.width
    height: eventDesc.visible ? eventDesc.y + eventDesc.height :
                                eventDay.height

    property alias day : eventDay.text
    property alias clock: eventClock.text
    property alias type: eventType.text
    property alias location: eventLocation.text
    property alias desc: eventDesc.text
    property alias colorFirstRow: eventDay.color
    property alias colorLocation: eventLocation.color
    property alias colorDesc: eventDesc.color

    Label {
        id: eventDay
        //text: day
        color: Theme.highlightColor
        x: Theme.horizontalPageMargin + Theme.fontSizeMedium*2.5 - width
    }

    Label {
        id: eventClock
        //text: clock
        color: colorFirstRow
        x: Theme.horizontalPageMargin + Theme.fontSizeMedium*3
    }

    Label {
        id: eventType
        //text: type
        color: colorFirstRow
        x: eventClock.x + Theme.fontSizeMedium*3
    }

    Label {
        id: eventLocation
        anchors {
            left: eventDay.horizontalCenter
            leftMargin: Theme.horizontalPageMargin
            top: eventDay.bottom
            right: parent.right
            rightMargin: Theme.horizontalPageMargin
        }
        //width: parent.width - x - Theme.horizontalPageMargin
        visible: eventDesc.visible
        color: Theme.secondaryHighlightColor
        //text: location
        wrapMode: Text.WrapAtWordBoundaryOrAnywhere
    }

    TextArea {
        id: eventDesc
        anchors {
            left: eventDay.horizontalCenter
            //left: eventLocation.left
            top: eventLocation.text === "" ? eventDay.bottom : eventLocation.bottom
            right: parent.right
            //rightMargin: eventLocation.anchors.rightMargin
        }
        color: Theme.highlightColor
        readOnly: true
        visible: false
        //text: description
        onClicked: {
            //console.log(" : : : : " + visible)
            visible = !visible
        }
    }

    onClicked: {
        eventDesc.visible = !eventDesc.visible
        if (eventDesc.visible){
            //console.log(eventLocation.text + "\n >>" + Utils.replaceChars(eventLocation.text)
            //            + "\n" + eventDesc.text + "\n >>" + Utils.replaceChars(eventDesc.text))
        }
    }

}

