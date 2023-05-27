import QtQuick 2.0
import Sailfish.Silica 1.0
import QtQuick.LocalStorage 2.0
import Nemo.Configuration 1.0

Dialog {
    id: page
    allowedOrientations: Orientation.All

    ConfigurationValue {
        id: showLocationSettings
        key: "/apps/patchmanager/show-event-location/url"
        defaultValue: "http://maps.google.com/maps?f=q&q="
    }

    DialogHeader {
        id: header
        title: qsTr("Search service")
    }

    SilicaFlickable {
        anchors {
            top: header.bottom
            left: parent.left
            right: parent.right
            bottom: parent.bottom
        }
        contentHeight: column.height

        PushUpMenu {
            MenuItem {
                text: "google"
                onClicked: {
                    searchUrl.text = "http://maps.google.com/maps?f=q&q="
                }
            }
            MenuItem {
                text: "bing"
                onClicked: {
                    searchUrl.text = "https://bing.com/maps/default.aspx?where1="
                }
            }
            MenuItem {
                text: "weGo"
                onClicked: {
                    searchUrl.text = "https://wego.here.com/directions/drive/"
                }
            }
        }

        Column {
            id: column

            TextField {
                id: searchUrl
                width: page.width
                text: showLocationSettings.url
                label: "search query"
            }

        }
    }

    onAccepted: {
        showLocationSettings.value = searchUrl.text
    }

}
