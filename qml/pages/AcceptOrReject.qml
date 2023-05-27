import QtQuick 2.0
import Sailfish.Silica 1.0

Dialog {
    id: page

    property alias title: header.title
    property alias desc: description.text

    DialogHeader{
        id: header
    }

    Label {
        id: description
        text: ""
        anchors {
            left: parent.left
            leftMargin: Theme.horizontalPageMargin
            right: parent.right
            rightMargin: Theme.horizontalPageMargin
            top: header.bottom
            topMargin: Theme.paddingLarge
        }
        color: Theme.secondaryHighlightColor
        width: parent.width - 2*x
        wrapMode: Text.WrapAtWordBoundaryOrAnywhere
    }
}
