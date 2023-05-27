#include "icsfilter.h"
#include <QtGlobal>
#include <QDebug>
#include <QJsonDocument>
#include <QJsonArray>
#include <QFile>
#include <QDir>
#include <QDate>
#include <QDateTime>
#include <QTimeZone>

/* example filter definition file
 * if no filter is defined, the ics-file is not modified
 * filter definitions are a JSON-file:
 * { "calendars": [
 *   { "label": "haka", // filter the ics-file, if mkcal->label = label
 *     "idProperty": "X-WR-CALNAME", // which property to use if mkcal->label or label is not defined, defaults to X-WR-CALNAME
 *     "idValue": "www.nimenhuuto.com/haka", // value of "property"
 * 	   "reminder": "120", // how many minutes before the start time - if not defined, a reminder is not set; overwrites the values in the ics-file
 *     "dayreminder": "18:00", // for full day events - if not defined, a reminder is not set for full day events; overwrites the values in the ics-file
 *     // if no filter is defined, the component is not filtered out
 *     "filters": [ // only one item per component type - uses only one if multiple found
 *     	{ "component": "vevent",
 *     	  "action": "accept", // accept, reject: take in or drop out components that match this filter, defaults to reject
 *     	  "propMatches": 0.0, // 0 - 100, how many percent of the listed values need to match - defaults to zero (one match is always enough)
 *        "properties": [ // only one item per property - uses only one if multiple found
 *        { "property": "class",
 *          "type": "string", // string, number, date, time, defaults to string
 *          "valueMatches": 0.0, // 0 - 100, how many percent of the listed values need to match - defaults to zero (one match is always enough)
 *          "values": [
 *          { "criteria": "s", // =, != (or <>), <, >, <=, >=, s, !s (substring)
 *            "value": "ottelu"
 *          },
 *          { "criteria": "s",
 *            "value": "muu" // =, != (or <>), <, >, <=, >=, s, !s (substring)
 *          }]
 *        },
 *        { "property": "dtstart",
 *          "type": "time", // string, number, date, time, defaults to string
 *          "valueMatches": 100, // percent
 *          "values": [
 *          { "criteria": "!=",
 *            "value": "20:30"
 *          }]
 *        }]
 *      }]
 *    }]
 *  }
*/

icsFilter::icsFilter(QObject *parent) : QObject(parent)
{
    filtersPath = QDir().homePath() + ".config/icsFilter/"; //
    filtersFileName = "icsCalendarFilters.json";
}

int icsFilter::addAlarm(int lineNr, int nrLines, int reminderMin, QTime reminderTime)
{
    int i, result = 0;
    QString component, prName, prValue;
    QStringList paNames, paValues;
    QDate date;
    QTime time;
    QDateTime dateTime;

    i = 0;
    while (i < nrLines) {
        readProperty(modLines[lineNr + i], prName, paNames, paValues, prValue);
        if (i == 0) { // "begin:vevent"
            component = prValue;
        } else if (prName.toLower() == dtstart) {
            dateTime = propertyTime(prName, prValue, paNames, paValues, date, time);
            i = nrLines;
        }// else if (prName.toLower() == "begin" &&
        //           prValue.toLower() == valarm) {
        //    alarmExists = true;
        //}
        i++;
    }
    // alarms can only be included into velement and vtodo
    if (isAlarmAllowed(component)) {
        lineNr +=  nrLines - 1;
        if (dateTime.isValid()) {
            result = addAlarmRelative(reminderMin, lineNr);
            qDebug() << "added relative alarm" << reminderMin << "min";
        } else if (reminderTime.isValid()) {
            qDebug() << "added absolute alarm" << reminderTime.toString("hh:mm");
            result = addAlarmAbsolute(reminderTime, date, lineNr);
        }
    }

    return result;
}

int icsFilter::addAlarmAbsolute(QTime time, QDate date, int lineNr) {
    QDateTime trigger;
    QString alarmStr;
    int i0 = lineNr;

    trigger.setDate(date.addDays(-1));
    trigger.setTime(time);
    trigger.setTimeSpec(Qt::LocalTime);

    alarmStr.append(trigger.toString("yyyy") + trigger.toString("MM") + trigger.toString("dd") + "T" + trigger.toString("HH") + trigger.toString("mm") + trigger.toString("ss"));
    qDebug() << alarmStr;

    origLines.insert(lineNr, "BEGIN:VALARM");
    modLines.insert(lineNr, "BEGIN:VALARM");
    lineNr++;
    origLines.insert(lineNr, "TRIGGER;VALUE=DATE-TIME:" + alarmStr); // TRIGGER:-PT30M
    modLines.insert(lineNr, "TRIGGER;VALUE=DATE-TIME:" + alarmStr); // TRIGGER:-PT30M
    lineNr++;
    origLines.insert(lineNr, "ACTION:AUDIO");
    modLines.insert(lineNr, "ACTION:AUDIO");
    lineNr++;
    origLines.insert(lineNr, "END:VALARM");
    modLines.insert(lineNr, "END:VALARM");
    lineNr++;
    return lineNr - i0;
}

int icsFilter::addAlarmRelative(int min, int lineNr)
{
    QString advance = "PT";
    int i0 = lineNr;
    if (min > 0) {
        advance.insert(0, "-");
        advance.append(QString().setNum(min));
    } else {
        advance.append(QString().setNum(-min));
    }
    advance.append("M");
    origLines.insert(lineNr, "BEGIN:VALARM");
    modLines.insert(lineNr, "BEGIN:VALARM");
    lineNr++;
    origLines.insert(lineNr, "TRIGGER:" + advance); // TRIGGER:-PT30M
    modLines.insert(lineNr, "TRIGGER:" + advance); // TRIGGER:-PT30M
    lineNr++;
    origLines.insert(lineNr, "ACTION:AUDIO");
    modLines.insert(lineNr, "ACTION:AUDIO");
    lineNr++;
    origLines.insert(lineNr, "END:VALARM");
    modLines.insert(lineNr, "END:VALARM");
    lineNr++;
    return lineNr - i0;
}

// checks if             calendarName = filter."label".value or
//           ics."X-WR-CALNAME".value = filter."value".value
bool icsFilter::calendarFilterCheck(QJsonValue filterN,
        QString filterKey, QStringList properties, QStringList values)
{
    QJsonValue jsonVal;
    QJsonObject calObj;
    QString filteringLabel, filteringProperty, filteringValue;
    int j, jN;
    bool result;

    result = false;
    if (filterN.isObject()) {
        calObj = filterN.toObject();
        jsonVal = calObj.value(filterKey);
        if (filterKey.toLower() == keyName) {
            if (!jsonVal.isUndefined() && jsonVal.isString()) {
                filteringLabel = jsonVal.toString();
                if (filteringLabel.toLower() == calendarName.toLower()) {
                    result = true;
                }
            }
        } else {
            //jsonVal = calObj.value(filterKey);
            if (!jsonVal.isUndefined() && jsonVal.isString()) {
                filteringProperty = jsonVal.toString();
            } else {
                filteringProperty = keyRemoteName;
            }

            jsonVal = calObj.value(keyIdVal);
            if (!jsonVal.isUndefined() && jsonVal.isString()) {
                filteringValue = jsonVal.toString();
            }
            j = 0;
            jN = properties.length();
            while (j < jN) {
                if (properties.at(j).toLower() == filteringProperty.toLower()) {
                    if (values.at(j).toLower() == filteringValue.toLower()) {
                        result = true;
                        j = jN;
                    }
                }
                j++;
            }
        }
    } else {
        qDebug() << "Filter is not a jsonValue";
    }

    if(result) {
        if (filteringValue.isEmpty()) {
            filteringValue = calendarName;
        }
        qDebug() << "Found filter for calendar" << filteringValue;
    }

    return result;
}

// checks, if the value of the filterKey ("label" or "X-WR-CALNAME")
// fits the calendar name or the corresponding ics-calendar property
QJsonObject icsFilter::calendarFilterFind(QString filterKey,
        QStringList properties, QStringList values)
{
    QJsonValue jsonVal;
    QJsonArray jsonArr;
    QJsonObject result;
    int i, iN;

    jsonVal = filters.value(keyCalendars);
    if (jsonVal.isArray()) {
        jsonArr = jsonVal.toArray();
        i = 0;
        iN = jsonArr.count();
        while (i < iN) {
            jsonVal = jsonArr.at(i);
            if (calendarFilterCheck(jsonVal, filterKey, properties,
                                    values)) {
                result = jsonVal.toObject();
                i = iN;
            }
            i++;
        }
    } else {
        if (calendarFilterCheck(jsonVal, filterKey, properties, values)) {
            result = jsonVal.toObject();
        }
    }

    return result;
}

// checks, which filter to use for this calendar
QJsonObject icsFilter::calendarFilterGet(QStringList properties,
                                         QStringList values)
{
    QJsonObject result;

    //{ "calendars": [{
    //    "label": "haka", // which calendar to filter
    //    "idProperty": "X-WR-CALNAME", // which property to use if label is not defined
    //    "idValue": "www.nimenhuuto.com/haka", // value of "property"

    // find correct calendar by label
    // if not found, find by property and value
    result = calendarFilterFind(keyName, properties, values);
    if (result.isEmpty()) {
        result = calendarFilterFind(keyIdProperty, properties, values);
    }

    return result;
}
/*
bool icsFilter::clearNewFilter()
{
    QStringList keys;
    int i;
    keys = newFilter.keys();
    i = keys.length() - 1;
    while (i >= 0) {
        newFilter.remove(keys.at(i));
        i--;
    }

    return newFilter.isEmpty();
}
// */

// reads the filter for the component
bool icsFilter::componentFilter(QString component,
            QJsonObject &cmpFilter, bool &isReject, float &matchPortion)
{
    QJsonValue jval;
    bool result;

    isReject = true; // default - "action": "reject"
    matchPortion = 0; // default - "propMatches": 0
    cmpFilter = listItem(cFilter, keyFilters, keyComponent, component);

    jval = cmpFilter.value(keyAction);
    if (jval.isString()) {
        if (jval.toString().toLower() == valueAccept) {
            isReject = false;
        }
    }

    jval = cmpFilter.value(keyPropMatches);
    if (jval.isString()) {
        matchPortion = jval.toDouble();
    }

    if (cmpFilter.isEmpty()) {
        result = false;
    } else {
        result = true;
    }

    return result;
}

/*
// reads the existing filter to newFilter and modifies its properties
QString icsFilter::createFilterCalendar(QString label, QString idProperty,
                QString idValue, QString reminder, QString reminderDay)
{
    // check if "label" = label or "idProperty"= idProperty && "idValue" = idValue exists already
    // returns the filter as a JSON-file
    QJsonObject jObject;
    QStringList properties, values;
    QString result;

    // check input
    if (label.isEmpty() && (idProperty.isEmpty() || idValue.isEmpty())) {
        return "-";
    }

    // read the current filter for the calendar
    if(readFilters("")) {
        if (!label.isEmpty()) {
            properties.append(keyName);
            values.append(label);
        } else if (!idProperty.isEmpty() && !idValue.isEmpty()) {
            properties.append(keyIdProperty);
            values.append(idProperty);
            properties.append(keyIdVal);
            values.append(idValue);
        }
        if (properties.length() > 0) {
            newFilter = calendarFilterGet(properties, values);
        }
    }

    // overwrite all properties, or create a new entry
    if (!newFilter.isEmpty()) {
        newFilter.remove(keyName);
        newFilter.remove(keyIdProperty);
        newFilter.remove(keyIdVal);
        newFilter.remove(keyReminder);
        newFilter.remove(keyReminderDay);
    }
    if (!label.isEmpty()) {
        newFilter.insert(keyName, label);
    }
    if (!idProperty.isEmpty()) {
        newFilter.insert(keyIdProperty, idProperty);
    }
    if (!idValue.isEmpty()) {
        newFilter.insert(keyIdVal, idValue);
    }
    if (!reminder.isEmpty()) {
        newFilter.insert(keyReminder, reminder);
    }
    if (!reminderDay.isEmpty()) {
        newFilter.insert(keyReminderDay, reminderDay);
    }

    result = QJsonDocument(newFilter).toJson();

    return result;
}

// overwrites the component parameters in newFilter
int icsFilter::createFilterComponent(QString component,
                                     int action, float percentMatches)
{
    // action: < 0 - "accept", 0 - undefined, > 0 - "reject"
    int i;
    QJsonObject jObj;
    QJsonValue jVal;
    QJsonArray jArr;

    if (newFilter.isEmpty()) {
        qWarning() << "New filter is not initialized.";
        return -2;
    }
    if (component.isEmpty()) {
        qWarning() << "No component specified.";
        return -1;
    }

    // find the component entry and replace it, or create a new one
    i = listItemIndex(newFilter, keyFilters, keyComponent, component);
    if (i >= 0 && i < newFilter.value(keyFilters).toArray().count()) {
        jArr = newFilter.value(keyFilters).toArray();
        jObj = jArr.at(i).toObject();
        jArr.removeAt(i);
    } else if (i == -1) {
        jObj = newFilter.value(keyFilters).toObject();
    } else { // no previous entry for component == component or no component entries
        jVal = newFilter.value(keyFilters);
        // copy the existing array, or make an array of the existing single filter entry
        if (jVal.isArray()) {
            jArr = jVal.toArray();
        } else if (jVal.isObject() &&
                   jVal.toObject().contains(keyComponent) &&
                   jVal.toObject().contains(keyProperties)) {
            jArr.append(jVal.toObject());
        }
    }

    // overwrite filter parameters
    jObj.remove(keyAction);
    jObj.remove(keyPropMatches);
    if (action < 0) {
        jObj.insert(keyAction, valueAccept);
    } else if (action > 0) {
        jObj.insert(keyAction, valueReject);
    }
    if (percentMatches >= 0) {
        jObj.insert(keyPropMatches, percentMatches);
        if (percentMatches > 1) {
            qWarning() << "Required number of matches more than 100 %: " << percentMatches*100 << "%";
        }
    }

    if (i < 0) {
        jArr.append(jObj);
    } else {
        jArr.insert(i, jObj);
    }

    // overwrite filters
    newFilter.insert(keyFilters, jArr);

    return jArr.count();
}

// overwrites the component property list in newFilter
int icsFilter::createFilterProperty(QString component, QString property,
                                    QString type, float percentMatches)
{
    int iF, iP = -2;
    QJsonObject fObj, pObj;
    QJsonValue jVal;
    QJsonArray fArr, pArr;

    if (newFilter.isEmpty()) {
        qWarning() << "New filter is not initialized.";
        return -2;
    }
    if (component.isEmpty()) {
        qWarning() << "No component specified.";
        return -1;
    }
    if (property.isEmpty()) {
        qWarning() << "No property specified.";
        return -1;
    }

    // find the component entry and replace it, or create a new one
    iF = listItemIndex(newFilter, keyFilters, keyComponent, component);
    if (iF >= 0 && iF < newFilter.value(keyFilters).toArray().count()) {
        fArr = newFilter.value(keyFilters).toArray();
        fObj = fArr.at(iF).toObject();
        fArr.removeAt(iF);
    } else if (iF == -1) {
        fObj = newFilter.value(keyFilters).toObject();
    } else { // no previous entry for component == component or no component entries
        jVal = newFilter.value(keyFilters);
        // copy the existing array, or make an array of the existing single filter entry
        if (jVal.isArray()) {
            fArr = jVal.toArray();
        } else if (jVal.isObject() &&
                   jVal.toObject().contains(keyComponent) &&
                   jVal.toObject().contains(keyProperties)) {
            fArr.append(jVal.toObject());
        }
        fObj.insert(keyComponent, component);
    }

    // overwrite properties-list
    if (fObj.contains(keyProperties)) {
        iP = listItemIndex(fObj, keyProperties, keyProperty, property);
        if (iP >= 0 && iP < fObj.value(keyProperties).toArray().count()) {
            pArr = fObj.value(keyProperties).toArray();
            pObj = pArr.at(iP).toObject();
            pArr.removeAt(iP);
        } else if (iP == -1) {
            pObj = fObj.value(keyProperties).toObject();
        } else { // no previous entry for property == property or no property entries
            jVal = fObj.value(keyProperties);
            // copy the existing array, or make an array of the existing single filter entry
            if (jVal.isArray()) {
                pArr = jVal.toArray();
            } else if (jVal.isObject() &&
                       jVal.toObject().contains(keyProperty) &&
                       jVal.toObject().contains(keyValues)) {
                pArr.append(jVal.toObject());
            }
            pObj.insert(keyProperty, property);
        }
    }

    // reset the parameters
    pObj.remove(keyPropType);
    if (!type.isEmpty()) {
        pObj.insert(keyPropType, type);
    }
    pObj.remove(keyValueMatches);
    if (percentMatches >= 0) {
        pObj.insert(keyValueMatches, percentMatches);
        if (percentMatches > 1) {
            qWarning() << "Required number of matches more than 100 %: " << percentMatches*100 << "%";
        }
    }

    if (iP < 0) {
        pArr.append(pObj);
    } else {
        pArr.insert(iP, pObj);
    }

    // overwrite properties-list
    fObj.insert(keyProperties, pArr);

    if (iF < 0) {
        fArr.append(fObj);
    } else {
        fArr.insert(iF, fObj);
    }

    // overwrite filters
    newFilter.insert(keyFilters, fArr);

    return pArr.count();
}

// to overwrite, method = "replace" || "overwrite"
int icsFilter::createFilterValue(QString method, QString component, QString property, QString criteria, QString value)
{
    bool isOverWrite = false;
    if (method.toLower() == "replace" || method.toLower() == "overwrite") {
        isOverWrite = true;
    }

    return createFilterValue(isOverWrite, component, property, criteria, value);
}

int icsFilter::createFilterValue(bool isOverWrite, QString component, QString property, QString criteria, QString value)
{
    // if isOverWrite, remove other filtering criterias for the property
    int iF, iP = -2;
    QJsonObject fObj, pObj, cObj;
    QJsonValue jVal;
    QJsonArray fArr, pArr, cArr;

    if (newFilter.isEmpty()) {
        qWarning() << "New filter is not initialized.";
        return -2;
    }
    if (component.isEmpty()) {
        qWarning() << "No component specified.";
        return -1;
    }
    if (property.isEmpty()) {
        qWarning() << "No property specified.";
        return -1;
    }
    if (value.isEmpty()) {
        qWarning() << "No value specified.";
        return -1;
    }
    if (criteria.isEmpty()) {
        qWarning() << "No criteria specified.";
        return -1;
    }

    // find the component entry and replace it, or create a new one
    iF = listItemIndex(newFilter, keyFilters, keyComponent, component);
    if (iF >= 0 && iF < newFilter.value(keyFilters).toArray().count()) {
        fArr = newFilter.value(keyFilters).toArray();
        fObj = fArr.at(iF).toObject();
        fArr.removeAt(iF);
    } else if (iF == -1) {
        fObj = newFilter.value(keyFilters).toObject();
    } else { // no previous entry for component == component or no component entries
        jVal = newFilter.value(keyFilters);
        // copy the existing array, or make an array of the existing single filter entry
        if (jVal.isArray()) {
            fArr = jVal.toArray();
        } else if (jVal.isObject() &&
                   jVal.toObject().contains(keyComponent) &&
                   jVal.toObject().contains(keyProperties)) {
            fArr.append(jVal.toObject());
        }
        fObj.insert(keyComponent, component);
    }

    // overwrite properties-list
    if (fObj.contains(keyProperties)) {
        iP = listItemIndex(fObj, keyProperties, keyProperty, property);
        if (iP >= 0 && iP < fObj.value(keyProperties).toArray().count()) {
            pArr = fObj.value(keyProperties).toArray();
            pObj = pArr.at(iP).toObject();
            pArr.removeAt(iP);
        } else if (iP == -1) {
            pObj = fObj.value(keyProperties).toObject();
        } else { // no previous entry for property == property or no property entries
            jVal = fObj.value(keyProperties);
            // copy the existing array, or make an array of the existing single filter entry
            if (jVal.isArray()) {
                pArr = jVal.toArray();
            } else if (jVal.isObject() &&
                       jVal.toObject().contains(keyProperty) &&
                       jVal.toObject().contains(keyValues)) {
                pArr.append(jVal.toObject());
            }
            pObj.insert(keyProperty, property);
        }
    }

    // modify the criteria list
    if (pObj.contains(keyValues) && !isOverWrite) {
        jVal = pObj.value(keyValues);
        if (jVal.isArray()) {
            cArr = jVal.toArray();
        } else if (jVal.isObject() &&
                   jVal.toObject().contains(keyCriteria) &&
                   jVal.toObject().contains(keyValue)) {
            cArr.append(jVal.toObject());
        }
    }
    cObj.insert(keyCriteria, criteria);
    cObj.insert(keyValue, value);
    cArr.append(cObj);

    // overwrite filtering criteria for the property, and update the list
    pObj.insert(keyValues, cArr);
    if (iP < 0) {
        pArr.append(pObj);
    } else {
        pArr.insert(iP, pObj);
    }

    // overwrite the list of properties, and update the filters list
    fObj.insert(keyProperties, pArr);
    if (iF < 0) {
        fArr.append(fObj);
    } else {
        fArr.insert(iF, fObj);
    }

    // overwrite filters
    newFilter.insert(keyFilters, fArr);

    return cArr.count();
}
// */

QString icsFilter::criteriaToString(filteringCriteria crit)
{
    //{NotDefined, Equal, NotEqual, EqualOrLarger, EqualOrSmaller,
    //  Larger, Smaller, SubString, NotSubString};
    QString result;
    if (crit == NotDefined) {
        result = "NotDefined";
    } else if (crit == Equal) {
        result = "Equal";
    } else if (crit == NotEqual) {
        result = "NotEqual";
    } else if (crit == EqualOrLarger) {
        result = "EqualOrLarger";
    } else if (crit == EqualOrSmaller) {
        result = "EqualOrSmaller";
    } else if (crit == Larger) {
        result = "Larger";
    } else if (crit == Smaller) {
        result = "Smaller";
    } else if (crit == SubString) {
        result = "SubString";
    } else if (crit == NotSubString) {
        result = "NotSubString";
    }

    return result;
}

// starts at lineNr
// returns the line number of the next 'end:vcalendar'
int icsFilter::filterCalendar(int lineNr)
{
    // assumes that the caledar properties, that are used for
    // identifying the filters, are before the first calendar component
    QRegExp beginCal, endCal, beginCmp, endCmp;
    QString component, prop, val;
    QStringList properties, values, params, parVals;
    QVector<QStringList> propParams, propParVals;
    QJsonValue jval;
    QTime reminderTime;
    //const int notValidAlarm = -(32*24*60*60 + 3);
    int i, line0, newRows, rows, reminderMin;
    bool addReminder = false, isFilterSet, isOk, notEndOfCal = true;

    beginCal.setCaseSensitivity(Qt::CaseInsensitive);
    beginCal.setPattern(("^begin:vcalendar$"));
    endCal.setCaseSensitivity(Qt::CaseInsensitive);
    endCal.setPattern(("^end:vcalendar$"));
    beginCmp.setCaseSensitivity(Qt::CaseInsensitive);
    endCmp.setCaseSensitivity(Qt::CaseInsensitive);

    // find the beginning of the calendar
    while (lineNr < modLines.length() &&
           beginCal.indexIn(modLines[lineNr]) < 0) {
        lineNr++;
    }
    lineNr++; // "begin:vcalendar" on line lineNr-1;
    line0 = lineNr;
    //qDebug() << "kalenteri löytyi riviltä" << lineNr-1;

    if (lineNr >= modLines.length()) {
        qWarning() << beginCal.pattern() << "not found";
        return lineNr;
    }

    // read the calendar properties
    // calendarName = mClient->key("label") || property("X-WR-CALNAME")
    while (lineNr < modLines.length() && notEndOfCal) {
        if (endCal.indexIn(modLines[lineNr]) >= 0) {
            notEndOfCal = false;
        } else {
            if (skipComponent(lineNr) == 0) {
                readProperty(modLines[lineNr], prop, params, parVals, val);
                properties.append(prop);
                values.append(val);
                propParams.append(params);
                propParVals.append(parVals);
            }
            lineNr++;
        }
    }

    // read the filter for the calendar
    cFilter = calendarFilterGet(properties, values);
    isFilterSet = !cFilter.isEmpty();

    // alarms
    if (isFilterSet) {
        jval = cFilter.value(keyReminder);
        if (!jval.isUndefined()) {
            if (jval.isString()) {
                reminderMin = jval.toString().toInt(&isOk);
                if (!isOk) {
                    qWarning() << "Converting reminder duration failed:" << jval.toString() << ". Using" << reminderMin << "minutes.";
                } else {
                    addReminder = true;
                    qWarning() << "Reminder for normal events" << reminderMin << "min before the event.";
                }
            } else if (jval.isDouble()) {
                reminderMin = jval.toDouble();
                addReminder = true;
                qWarning() << "Reminder for normal events" << reminderMin << "min before the event.";
            } else {
                qWarning() << "Converting reminder duration failed: the reminder is not a string nor a number.";
            }
        } else {
            qWarning() << "No reminder set for normal events.";
        }
        jval = cFilter.value(keyReminderDay);
        if (!jval.isUndefined()) {
            if (jval.isString()) {
                reminderTime = QTime::fromString(jval.toString(), "h:mm");
                if (!reminderTime.isValid()) {
                    qWarning() << "Converting dayreminder time failed:" << jval.toString();
                } else {
                    qWarning() << "Reminder for full day events at" << reminderTime.toString("hh:mm");
                }
            } else {
                qWarning() << "Converting dayreminder time failed: the reminder is not a valid string.";
            }
        } else {
            qWarning() << "No reminder set for full day events.";
        }
    }

    // filter the events
    lineNr = line0;
    while (lineNr < modLines.length() && endCal.indexIn(modLines[lineNr]) < 0) {
        component.clear();
        lineNr = findComponent(lineNr, component);
        if (isFilterSet) {
            rows = filterComponent(component, lineNr);
            if (rows < 0) { // filter out if rows < 0
                qDebug() << "Filtering out rows" << lineNr+1 << "-" << lineNr - rows << ".";
                beginCmp.setPattern("^begin:" + component);
                endCmp.setPattern("^end:" + component);
                if (beginCmp.indexIn(modLines[lineNr]) < 0) {
                    qWarning() << "!!! The first row is NOT " << beginCmp.pattern();
                }
                if (endCmp.indexIn(modLines[lineNr - rows - 1]) < 0) {
                    qWarning() << "!!! The last row is NOT " << endCmp.pattern();
                }
                i = lineNr;
                while ((i <= lineNr - rows - 1 || modLines[i] == " ")
                       && i < modLines.length()) { // onko modLines[i] == " " tarpeen???
                    modLines[i] = "";
                    i++;
                }
                lineNr = i - 1;
            } else {
                if (addReminder || reminderTime.isValid()) {
                    newRows = addAlarm(lineNr, rows, reminderMin, reminderTime);
                    lineNr += newRows;
                }
                lineNr += rows - 1; // "end:vevent"
            }
        }
        lineNr ++;
    }

    return lineNr;
}

// returns the number of lines checked
// if result < 0, the lines should be filtered out
// if result > 0, the lines should not be filtered out
int icsFilter::filterComponent(QString component, int lineNr)
{
    int iProp, result, isMatch, matchSum, nrChecks;
    bool loop = true, isFilter = false;
    bool isReject;
    float percentMatches;
    QStringList properties, values, paNames, paValues;
    QVector<QStringList> parameterNames, parameterValues;
    QString prName, prValue;
    QJsonObject cmpFilter;
    //QDateTime dateTime;

    if (lineNr >= modLines.length()) {
        return 0;
    }

    // is a filter defined for the component
    isFilter = componentFilter(component, cmpFilter, isReject, percentMatches);
    if (!isFilter) {
        qDebug() << component  << ":" << "no filters.";
    }

    iProp = 0;
    isMatch = 0;
    matchSum = 0;
    nrChecks = 0;
    result = lineNr;
    lineNr++;
    while (loop && lineNr < modLines.length()) {
        readProperty(modLines[lineNr], prName, paNames, paValues, prValue);
        if (prName.toLower() == "begin") { // skip subcomponents
            qDebug() << "@" << lineNr+1 << "skip" << modLines[lineNr];
            lineNr = findComponentEnd(lineNr, prValue) + 1;
        } else if (prName.toLower() == "end") { // && prValue.toLower() == component.toLower()) {
            qDebug() << "@" << lineNr+1 << modLines[lineNr];
            loop = false;
        } else if (!prName.isEmpty()) {
            iProp++;
            properties.append(prName);
            values.append(prValue);
            parameterNames.append(paNames);
            parameterValues.append(paValues);

            if (isFilter) {
                isMatch = isPropertyMatching(cmpFilter, prName, prValue, paNames, paValues);
                matchSum += isMatch;
                nrChecks++;
                if ((percentMatches == 0 && isMatch > 0) || (percentMatches == 1 && isMatch < 0)) {
                    loop = false;
                }
                if (isMatch > 0) {
                    qDebug() << prName << prValue << matchSum;
                }
            }
        }
        lineNr ++;
    }
    // find the last line of the component
    if (prName.toLower() != "end") {
        lineNr = findComponentEnd(lineNr, component);
    }

    result = lineNr - result; // number of lines in the component

    // if isMatch = 0, the last property was not included in the filter
    // a match is found if isMatch > 0 or isMatch == 0 && matchSum > 0
    //if (isMatch == 0 && matchSum > 0) {
    //    isMatch = 1;
    //}
    if (matchSum > 0 && matchSum >= percentMatches*nrChecks) {
        isMatch = 1;
    }
    // reject (result < 0) if
    // - isReject == true && a match is found
    // - isReject == false && a match is not found
    if ((isReject && isMatch > 0) || (!isReject && isMatch <= 0)) {
        result = -result;
    }

    //if (result < 0) {
    //    if (isReject) {
    //        qDebug() << "Rejecting for matching the filter.";
    //    } else {
    //        qDebug() << "Rejecting for not matching the filter.";
    //    }
    //}

    return result;
}

QByteArray icsFilter::filterIcs(QString label, QByteArray origIcsData, QString filters)
{
    // label tells which ics-filter to use.
    // If label is empty, calendar-property "X-WR-CALNAME" defines
    // the used filter.
    // filters should be a json-string. If it is empty, tries to read
    // ======>  ~/.config/icsFilter/filters.json  <=======
    // Copies origIcsData to origLines[] and modLines[], where
    // modLines[] will be filtered. Lines to be filtered out will
    // be replaced by an empty line "". Unfolding will replace
    // the folded lines by " ".
    // resultIcs = origLines[i] + "\r\n", if modLines[i] != ""
    QByteArray resultIcs;
    QString icsFile(origIcsData);
    int iLine, emptyEnds;

    calendarName = label;

    if (!readFilters(filters)) {
        qWarning() << "Reading filters unsuccessful. Ics-file not filtered." << filters.toLatin1();
        return origIcsData;
    }

    // the lines should end with CRLF
    origLines = icsFile.split("\r\n");
    if (origLines.length() < 2) {
        origLines = icsFile.split("\n");
    }
    modLines = origLines;

    unfoldLines();
    iLine = modLines.length() - 1;
    emptyEnds = 0;
    while (iLine > 0 && (modLines[iLine] == "" || modLines[iLine] == " ") ) {
        iLine--;
        emptyEnds++;
    }

    // filter each calendar in the file
    qDebug() << "Rows in the ics file" << modLines.length() << ".";
    //qDebug() << lineFolds << "line foldings";
    iLine = 0;
    while (iLine >= 0 && iLine < modLines.length() - emptyEnds) {
        iLine = filterCalendar(iLine) + 1;
    }

    // skip the filtered out = empty lines
    resultIcs = "";
    iLine = 0;
    while (iLine < modLines.length()) {
        if (modLines[iLine] != "") {
            resultIcs += origLines[iLine].toLatin1() + "\r\n";
        }
        iLine++;
    }

    return resultIcs;
}

QString icsFilter::filterIcs(QString label, QString origIcsData, QString filters) {
    return filterIcs(label, origIcsData.toLatin1(), filters);
}

icsFilter::filteringCriteria icsFilter::filterType(QJsonValue jVal,
                                                   propertyType vType)
{
    filteringCriteria result;
    QString cmp;

    result = NotDefined;
    if (jVal.isString()) {
        cmp = jVal.toString().toLower();
        if (cmp == "s") {
            result = SubString;
            if (vType != String) {
                qWarning() << "Criteria SubString defined for strings only.";
            }
        } else if (cmp == "!s") {
            result = NotSubString;
            if (vType != String) {
                qWarning() << "Criteria NotSubString defined for strings only.";
            }
        } else if (cmp == "=") {
            result = Equal;
        } else if (cmp == "!=" || cmp == "<>") {
            result = NotEqual;
        } else if (cmp == "<") {
            result = Smaller;
            if (vType == String) {
                qWarning() << "Criteria < not defined for strings.";
            }
        } else if (cmp == ">") {
            result = Larger;
            if (vType == String) {
                qWarning() << "Criteria > not defined for strings.";
            }
        } else if (cmp == "<=") {
            result = EqualOrSmaller;
            if (vType == String) {
                qWarning() << "Criteria <= not defined for strings.";
            }
        } else if (cmp == ">=") {
            result = EqualOrLarger;
            if (vType == String) {
                qWarning() << "Criteria >= not defined for strings.";
            }
        }
    }

    return result;
}

// searches for 'BEGIN:' or 'END:' +component starting from lineNr, and
// returns the begin-line number
// if component is empty, searches for any vcomponent
int icsFilter::findComponent(int lineNr,
                             QString &component, bool componentEnd)
{
    // searches for 'end:' if componentEnd == true
    bool search = true;
    QRegExp expression;

    if (component.isEmpty()) {
        component = "(v[a-z]+)";
    }
    expression.setCaseSensitivity(Qt::CaseInsensitive);
    expression.setMinimal(false);
    if (componentEnd) {
        //expression.setPattern("^end(\\s*):(\\s*)" + component);
        expression.setPattern("^end\\s*:\\s*" + component);
    } else {
        //expression.setPattern("^begin(\\s*):(\\s*)" + component);
        expression.setPattern("^begin\\s*:\\s*" + component);
    }

    while (search && lineNr < modLines.length()) {
        if (expression.indexIn(modLines[lineNr]) >= 0) {
            search = false;
            qDebug() << "@" << lineNr+1 << modLines[lineNr];
        } else {
            lineNr++;
        }
    }

    if (component == "(v[a-z]+)" && expression.captureCount() > 0) {
        component = expression.cap(expression.captureCount());
    }

    return lineNr;
}

int icsFilter::findComponentEnd(int lineNr, QString component)
{
    return findComponent(lineNr, component, true);
}

bool icsFilter::isAlarmAllowed(QString component)
{
    bool result = false;
    if (component.toLower() == vevent ||
            component.toLower() == vtodo) {
        result = true;
    }
    return result;
}

int icsFilter::isMatchingDate(QJsonValue jVal, filteringCriteria crit,
                              QString prop, QString value)
{
    QDate dateFilter, dateProperty;
    QRegExp dateValue;
    bool isOk;
    int result, yyyy = 0, mm = 0, dd = 0;

    isOk = false;
    if (jVal.isString()) {
        dateFilter = QDate::fromString(jVal.toString());
    }
    if (dateFilter.isValid()) {
        isOk = true;
    } else {
        qWarning() << "Filter value is not a date:" << jVal.toString();
        return 0;
    }

    //DTSTART:19970714T133000 // Local time
    //DTSTART:19970714T173000Z // UTC time
    //DTSTART;TZID=America/New_York:19970714T133000 // Local time and time zone reference
    dateValue.setPattern("(\\d\\d?\\d?\\d?)(\\d\\d)(\\d\\d)");
    if (dateValue.indexIn(value) >= 0) {
        yyyy = dateValue.cap(1).toInt(&isOk);
        if (isOk) {
            mm = dateValue.cap(2).toInt(&isOk);
            if (isOk) {
                dd = dateValue.cap(3).toInt(&isOk);
            }
        }
    }
    dateProperty.setDate(yyyy, mm, dd);
    if (!dateProperty.isValid()) {
        qWarning() << "Property value is not a date:" << prop << "=" << value;
        return 0;
    }

    if ( (crit == Equal && dateProperty == dateFilter) ||
         (crit == NotEqual && dateProperty != dateFilter) ||
         (crit == Larger && dateProperty > dateFilter) ||
         (crit == EqualOrLarger && dateProperty >= dateFilter) ||
         (crit == Smaller && dateProperty < dateFilter) ||
         (crit == EqualOrSmaller && dateProperty <= dateFilter)
         ) {
            result = matchSuccess;
    } else {
        result = matchFail;
    }

    return result;
}

int icsFilter::isMatchingNumber(QJsonValue jVal, filteringCriteria crit,
                                QString prop, QString value)
{
    bool isOk;
    double dblFilter, dblProperty;
    int result;

    isOk = false;
    if (jVal.isString()) {
        dblFilter = jVal.toString().toDouble(&isOk);
    } else if (jVal.isDouble()) {
        dblFilter = jVal.toDouble();
        isOk = true;
    }
    if(!isOk) {
        qWarning() << "Filter value is not a number:" << jVal.toString();
        return 0;
    }

    dblProperty = value.toDouble(&isOk);
    if (!isOk) {
        qWarning() << "Property value is not a number:" << prop << ":" << value;
        return 0;
    }

    if ( (crit == Equal && dblProperty == dblFilter) ||
         (crit == NotEqual && dblProperty != dblFilter) ||
         (crit == Larger && dblProperty > dblFilter) ||
         (crit == EqualOrLarger && dblProperty >= dblFilter) ||
         (crit == Smaller && dblProperty < dblFilter) ||
         (crit == EqualOrSmaller && dblProperty <= dblFilter)
         ) {
        result = matchSuccess;
    } else {
        result = matchFail;
    }
    return result;
}

int icsFilter::isMatchingString(QJsonValue jVal, filteringCriteria crit,
                                QString prop, QString value)
{
    int result = 0;
    QString filterValue;

    if (!jVal.isString()) {
        qWarning() << "For property " << prop << ", the filter value is not a string:" << jVal.toString();
        return 0;
    }

    filterValue = jVal.toString();
    if ( (crit == Equal && value.compare(filterValue, Qt::CaseInsensitive) == 0) ||
         (crit == NotEqual && value.compare(filterValue, Qt::CaseInsensitive) != 0) ||
         (crit == SubString && value.contains(filterValue, Qt::CaseInsensitive)) ||
         (crit == NotSubString && !value.contains(filterValue, Qt::CaseInsensitive))) {
        result = matchSuccess;
    } else {
        result = matchFail;
    }

    //qDebug() << "merkkijonon" << filterValue << "vertailu jonoon" << value << "onko" << criteriaToString(crit) << "?" << result;

    return result;
}

int icsFilter::isMatchingTime(QJsonValue jVal, filteringCriteria crit, QString prop, QString value, QStringList parameters, QStringList parValues)
{
    //DTSTART:19970714T133000 // Local time
    //DTSTART:19970714T173000Z // UTC time
    //DTSTART;TZID=America/New_York:19970714T133000 // Local time and time zone reference
    QTime timeFilter, timeProperty;
    QRegExp dateValue;
    QDate date;
    QDateTime dateTime;
    int result;

    if (jVal.isString()) {
        timeFilter = QTime::fromString(jVal.toString(), "hh:mm");
    }
    if (!timeFilter.isValid()) {
        qWarning() << "Filter value is not a timevalue:" << jVal.toString();
        return 0;
    }
    dateTime = propertyTime(prop, value, parameters, parValues, date, timeProperty);

    if ( (crit == Equal && timeProperty == timeFilter) ||
         (crit == NotEqual && timeProperty != timeFilter) ||
         (crit == Larger && timeProperty > timeFilter) ||
         (crit == EqualOrLarger && timeProperty >= timeFilter) ||
         (crit == Smaller && timeProperty < timeFilter) ||
         (crit == EqualOrSmaller && timeProperty <= timeFilter)
         ) {
        result = matchSuccess;
    } else {
        result = matchFail;
    }

    return result;
}

// does property.value in the ics-calendar match cmpFilter
int icsFilter::isPropertyMatching(QJsonObject cmpFilter, QString property,
                                  QString value, QStringList parameters,
                                  QStringList parValues)
{
    // result < 0, if the current property does not match the filter
    // result > 0, if the current property matches the filter
    // result = 0, if no filters for the property were found
    int result = 0, match, i, iN, nrChecks, matchSum;
    QJsonArray jarr;
    QJsonObject prFilter, jobj;
    QJsonValue jval;
    propertyType valType;
    filteringCriteria criteria = NotDefined;
    QString filterValue;//, cmp;
    bool stillAnd;
    float percentMatches;

    // read the filters where properties[property] = property
    prFilter = listItem(cmpFilter, keyProperties, keyProperty, property);
    if (prFilter.isEmpty()) {
        return 0;
    }

    // type of the property value - string, number, date or time
    jval = prFilter.value(keyPropType);
    valType = String;
    if (jval.isString()) {
        filterValue = jval.toString().toLower();
        if (filterValue == "date") {
            valType = Date;
        } else if (filterValue == "number") {
            valType = Number;
        } else if (filterValue == "time") {
            valType = Time;
        }
    }

    // for a match, how many conditions does the property need to match?
    // 0 = single, 100 = all
    jval = prFilter.value(keyValueMatches);
    if (jval.isDouble()) {
        percentMatches = jval.toDouble();
    } else if (jval.isString()) {
        percentMatches = jval.toString().toFloat(); // toFloat() returns 0.0 if conversion fails
    } else {
        qWarning() << "Value of" << keyValueMatches << "is not a number or a string, but" << jval.type();
        percentMatches = 0;
    }
    if (percentMatches < 0 || percentMatches > 1) {
        qWarning() << "Amount of matches is not 0 - 100 %: " << percentMatches*100;
    }

    // check which filters the property value matches
    stillAnd = true; //
    nrChecks = 0;
    matchSum = 0;
    jval = prFilter.value(keyValues); // [ { "value": string, "criteria": string }]
    if (jval.isArray()) {
        //qDebug() << "löytyi arvolista" << "onko or?" << isOr;
        jarr = jval.toArray();
        i = 0;
        iN = jarr.count();
        while (i < iN && stillAnd) {
            match = 0;
            jval = jarr.at(i); // { "value": xx, "criteria": string }
            if (jval.isObject()) {
                jobj = jval.toObject();
                jval = jobj.value(keyCriteria);
                criteria = filterType(jval, valType);
                /*
                criteria = NotDefined;
                if (jval.isString()) {
                    cmp = jval.toString().toLower();
                    if (cmp == "s") {
                        criteria = SubString;
                        if (valType != String) {
                            qWarning() << "Criteria SubString defined for strings only.";
                        }
                    } else if (cmp == "!s") {
                        criteria = NotSubString;
                        if (valType != String) {
                            qWarning() << "Criteria NotSubString defined for strings only.";
                        }
                    } else if (cmp == "=") {
                        criteria = Equal;
                    } else if (cmp == "!=" || cmp == "<>") {
                        criteria = NotEqual;
                    } else if (cmp == "<") {
                        criteria = Smaller;
                        if (valType == String) {
                            qWarning() << "Criteria < not defined for strings.";
                        }
                    } else if (cmp == ">") {
                        criteria = Larger;
                        if (valType == String) {
                            qWarning() << "Criteria > not defined for strings.";
                        }
                    } else if (cmp == "<=") {
                        criteria = EqualOrSmaller;
                        if (valType == String) {
                            qWarning() << "Criteria <= not defined for strings.";
                        }
                    } else if (cmp == ">=") {
                        criteria = EqualOrLarger;
                        if (valType == String) {
                            qWarning() << "Criteria >= not defined for strings.";
                        }
                    }
                }
                // */

                jval = jobj.value(keyValue);
                if (valType == String) {
                    match = isMatchingString(jval, criteria, property, value);
                    /*
                    if (jval.isString()) {
                        filterValue = jval.toString();
                        qDebug() << "merkkijonon" << filterValue << "vertailu jonoon" << value << "onko" << criteriaToString(criteria) << "?";
                        if ( (criteria == Equal && filterValue == value) ||
                             (criteria == NotEqual && filterValue != value) ||
                             (criteria == SubString && value.contains(filterValue, Qt::CaseInsensitive)) ||
                             (criteria == NotSubString && !value.contains(filterValue, Qt::CaseInsensitive))) {
                            if (isOr) {
                                result = success;
                                stillAnd = false;
                                qDebug() << "löytyi" << value << result;
                            } else {
                                result += success;
                            }
                        } else {
                            result -= success;
                            qDebug() << filterValue << "ei kelpaa" << value << "vertailu" << criteriaToString(criteria) << "indexOf()" << value.indexOf(filterValue, Qt::CaseInsensitive);
                            if (!isOr) {
                                stillAnd = false;
                            }
                        }
                    }
                    // */
                } else if (valType == Number) { // Date, Time or Number
                    match = isMatchingNumber(jval, criteria, property, value);
                    /*
                        isOk = false;
                        if (jval.isString()) {
                            dblFilter = jval.toString().toDouble(&isOk);
                        } else if (jval.isDouble()) {
                            dblFilter = jval.toDouble();
                            isOk = true;
                        }
                        if(!isOk) {
                            qWarning() << "Filter value is not a number." << cmpFilter.value("id") << prFilter.value("id") << "values" << i;
                            return 0;
                        }

                        dblProperty = value.toDouble(&isOk);
                        if (!isOk) {
                            qWarning() << "Property value is not a number:" << property << ":" << value;
                            return 0;
                        }

                        if ( (criteria == Equal && dblProperty == dblFilter) ||
                             (criteria == NotEqual && dblProperty != dblFilter) ||
                             (criteria == Larger && dblProperty > dblFilter) ||
                             (criteria == EqualOrLarger && dblProperty >= dblFilter) ||
                             (criteria == Smaller && dblProperty < dblFilter) ||
                             (criteria == EqualOrSmaller && dblProperty <= dblFilter)
                             ) {
                            if (isOr) {
                                result = success;
                                stillAnd = false;
                            } else {
                                result += success;
                            }
                        } else {
                            if (!isOr) {
                                result -= success;
                                stillAnd = false;
                            }
                        }
                    // */
                } else if (valType == Date) {
                    match = isMatchingDate(jval, criteria, property, value);
                    /*
                    // yyyymmdd
                    isOk = false;
                    if (jval.isString()) {
                        dateFilter = QDate::fromString(jval.toString());
                    }
                    if (dateFilter.isValid()) {
                        isOk = true;
                    } else {
                        qWarning() << "Filter value is not a date:" << jval.toString();
                        return 0;
                    }

                    //DTSTART:19970714T133000 // Local time
                    //DTSTART:19970714T173000Z // UTC time
                    //DTSTART;TZID=America/New_York:19970714T133000 // Local time and time zone reference
                    dateValue.setPattern("(\\d\\d?\\d?\\d?)(\\d\\d)(\\d\\d)");
                    if (dateValue.indexIn(value) >= 0) {
                        yyyy = dateValue.cap(1).toInt(&isOk);
                        if (isOk) {
                            mm = dateValue.cap(2).toInt(&isOk);
                            if (isOk) {
                                dd = dateValue.cap(3).toInt(&isOk);
                            }
                        }
                    }
                    dateProperty.setDate(yyyy, mm, dd);
                    if (!dateProperty.isValid()) {
                        qWarning() << "Property value is not a date:" << property << ":" << value;
                        return 0;
                    }

                    if ( (criteria == Equal && dateProperty == dateFilter) ||
                         (criteria == NotEqual && dateProperty != dateFilter) ||
                         (criteria == Larger && dateProperty > dateFilter) ||
                         (criteria == EqualOrLarger && dateProperty >= dateFilter) ||
                         (criteria == Smaller && dateProperty < dateFilter) ||
                         (criteria == EqualOrSmaller && dateProperty <= dateFilter)
                         ) {
                        if (isOr) {
                            result = success;
                            stillAnd = false;
                        } else {
                            result += success;
                        }
                    } else {
                        if (!isOr) {
                            result -= success;
                            stillAnd = false;
                        }
                    }
                    // */
                } else if (valType == Time) {
                    match = isMatchingTime(jval, criteria, property, value, parameters, parValues);
                    /*
                    isOk = false;
                    if (jval.isString()) {
                        timeFilter = QTime::fromString(jval.toString(), "hh:mm");
                    }
                    if (timeFilter.isValid()) {
                        isOk = true;
                    } else {
                        qWarning() << "Filter value is not a timevalue:" << jval.toString();
                        return 0;
                    }
                    //DTSTART:19970714T133000 // Local time
                    //DTSTART:19970714T173000Z // UTC time
                    //DTSTART;TZID=America/New_York:19970714T133000 // Local time and time zone reference
                    //only local time supported at the moment
                    dateValue.setPattern("\\d+[Tt](\\d\\d)(\\d\\d)(\\d\\d)");
                    if (dateValue.indexIn(value) >= 0) {
                        hh = dateValue.cap(1).toInt(&isOk);
                        if (isOk) {
                            min = dateValue.cap(2).toInt(&isOk);
                            if (isOk) {
                                ss = dateValue.cap(3).toInt(&isOk);
                                timeProperty.setHMS(hh, min, ss);
                            }
                        }
                    }
                    if (!timeProperty.isValid()) {
                        isOk = false;
                        qWarning() << "Property value is not a timevalue:" << property << " - " << value;
                        qDebug() << dateValue.capturedTexts() << dateValue.cap(0) << dateValue.cap(1) << hh << dateValue.cap(2) << min << dateValue.cap(3) << ss;
                    }

                    if ( (criteria == Equal && timeProperty == timeFilter) ||
                         (criteria == NotEqual && timeProperty != timeFilter) ||
                         (criteria == Larger && timeProperty > timeFilter) ||
                         (criteria == EqualOrLarger && timeProperty >= timeFilter) ||
                         (criteria == Smaller && timeProperty < timeFilter) ||
                         (criteria == EqualOrSmaller && timeProperty <= timeFilter)
                         ) {
                        if (isOr) {
                            result = success;
                            stillAnd = false;
                        } else {
                            result += success;
                        }
                    } else {
                        if (!isOr) {
                            result -= success;
                            stillAnd = false;
                        }
                    }
                    // */
                }
                nrChecks++;
                if (match > 0) {
                    matchSum += match;
                    if (percentMatches == 0) {
                        stillAnd = false;
                    }
                } else {
                    if (percentMatches == 1) {
                        stillAnd = false;
                    }
                }

            }
            i++;
        }
    }

    if (matchSum > 0) {
        if (matchSum >= percentMatches*nrChecks) {
            result = 1;
        } else {
            result = -1;
        }
    } else {
        result = 0;
    }

    //if (result == 1) {
    //    qDebug() << property << criteriaToString(criteria);
    //}
    return result;
}

/*
// "calendars", "label", "idProperty", "idValue", "reminder", "dayreminder", "filters"
QString icsFilter::keysCalendar()
{
    QString result;
    result.append(keyCalendars);
    result.append(", ");
    result.append(keyName);
    result.append(", ");
    result.append(keyIdProperty);
    result.append(", ");
    result.append(keyIdVal);
    result.append(", ");
    result.append(keyReminder);
    result.append(", ");
    result.append(keyReminderDay);
    result.append(", ");
    result.append(keyFilters);

    return result;
}

// "component", "action", "propMatches", "properties"
QString icsFilter::keysComponent()
{
    QString result;
    result.append(keyComponent);
    result.append(", ");
    result.append(keyAction);
    result.append(", ");
    result.append(keyPropMatches);
    result.append(", ");
    result.append(keyProperties);

    return result;
}

QString icsFilter::keysProperty()
{
    QString result;
    result.append(keyProperty);
    result.append(", ");
    result.append(keyPropType);
    result.append(", ");
    result.append(keyValueMatches);
    result.append(", ");
    result.append(keyValues);

    return result;
}

QString icsFilter::keysValue()
{
    QString result;
    result.append(keyValue);
    result.append(", ");
    result.append(keyCriteria);

    return result;
}
// */

// returns the list item i where jObject.listName[i].key = value
QJsonObject icsFilter::listItem(QJsonObject jObject, QString listName,
                QString key, QString value, QString key2, QString value2)
{
    int i;
    QJsonObject result;
    i = listItemIndex(jObject, listName, key, value, key2, value2);
    if (i >= 0) {
        result = jObject.value(listName).toArray().at(i).toObject();
    } else if (i == -1) {
        result = jObject.value(listName).toObject();
    }
    return result;
}

// returns the index of the list item, where jObject.listName[i].key = value
int icsFilter::listItemIndex(QJsonObject jObject, QString listName, QString key, QString value, QString key2, QString value2)
{
    // returns -2 if listName[i].key != value
    // returns -1 if jObject.listName is not an array, but has key = value
    QJsonArray jArr;
    QJsonObject jObj;
    QJsonValue jVal, jVal2;
    int i, iN, result;
    bool isVal2Needed = key2.isEmpty();

    result = -2;
    jVal = jObject.value(listName);
    if (jVal.isArray()) {
        jArr = jVal.toArray();
        i = 0;
        iN = jArr.count();
        while (i < iN) {
            jVal = jArr.at(i);
            if (jVal.isObject()) {
                jObj = jVal.toObject();
                jVal = jObj.value(key);
                if (isVal2Needed) {
                    jVal2 = jObj.value(key2);
                }
                if (jVal.toString().toLower() == value.toLower() &&
                        (!isVal2Needed || jVal2.toString().toLower() == value2.toLower())) {
                    result = i;
                }

            }
            i++;
        }
    } else if (jVal.isObject()) {
        jObj = jVal.toObject();
        if (jObj.contains(key) && (!isVal2Needed || jObj.contains(key2))) {
            if (jObj.value(key).toString().toLower() == value.toLower() &&
                    (!isVal2Needed || jObj.value(key2).toString().toLower() == value2.toLower())) {
                result = -1;
            }
        }
    }

    return result;
}

QDateTime icsFilter::propertyTime(QString prop, QString timeStr,
                                  QStringList parameters,
                                  QStringList parValues,
                                  QDate &date, QTime &time)
{
    //DTSTART;VALUE=DATE:19970714 // day
    //DTSTART:19970714T133000 // Local time
    //DTSTART:19970714T173000Z // UTC time
    //DTSTART;TZID=America/New_York:19970714T133000 // Local time and time zone reference
    QDateTime result;
    QTimeZone zone;
    QRegExp dtValue("(\\d+)[Tt](\\d\\d)(\\d\\d)(\\d\\d)"), dValue("(\\d+)");
    QString tmp, zoneName;
    bool isOk;
    int hr=-1, min=-1, sec=-1, yyyy=0, mm=-1, dd=-1, i;
    // time zone
    if (timeStr.at(timeStr.length() - 1) == 'Z') {
        QTimeZone utc(0);
        zone.swap(utc);
    } else {
        i = 0;
        while (i < parameters.length()) {
            if (parameters.at(i).toLower() == "tzid") {
                zoneName = parValues.at(i);
                i = parameters.length();
                if (zone.isTimeZoneIdAvailable(zoneName.toLatin1())) {
                    QTimeZone zone2(zoneName.toLatin1());
                    zone.swap(zone2);
                } else {
                    qWarning() << "Time zone" << zoneName << "not available, using locale.\nAvailable time zones:" << '\n' << zone.availableTimeZoneIds();
                }
            }
            i++;
        }
    }
    // read time
    tmp = "";
    i = dtValue.indexIn(timeStr);
    if ( i >= 0) {
        hr = dtValue.cap(2).toInt(&isOk);
        if (isOk) {
            min = dtValue.cap(3).toInt(&isOk);
            if (isOk) {
                sec = dtValue.cap(4).toInt(&isOk);
            }
        }
        time.setHMS(hr, min, sec);
        tmp = dtValue.cap(1);
    } else {
        i = dValue.indexIn(timeStr);
        if (i >= 0) {
            tmp = dValue.cap(1);
        }
    }
    if (tmp.length() >= 5) {
        yyyy = tmp.leftRef(tmp.length() - 4).toInt();
        mm = tmp.midRef(tmp.length() - 4, 2).toInt();
        dd = tmp.rightRef(2).toInt();
    }
    date.setDate(yyyy, mm, dd);

    result.setDate(date);
    result.setTime(time);
    if (zone.isValid()) {
        result.setTimeZone(zone);
    } else {
        result.setTimeSpec(Qt::LocalTime);
    }

    if (!date.isValid()) {
        qWarning() << "Property value is not a timevalue:" << prop << " - " << timeStr << " - " << zoneName;
        qDebug() << "date-time?" << dtValue.capturedTexts() << "or date?" << dValue.capturedTexts();
    }

    return result.toLocalTime();
}

/*
QString icsFilter::readCalendarFilters(QString label)
{
    QString result;


    return result;
}
//*/

bool icsFilter::readFilters(QString filtersFileContents)
{
    // reads filters from fileName if fileContents.isEmpty()
    QJsonDocument json;
    const int filtersFileMinLength = 16; // {"calendars":[]}

    if (filtersFileContents.length() < filtersFileMinLength) {
        filtersFileContents = readFiltersFile();
    }
    if (filtersFileContents.length() < filtersFileMinLength) {
        return false;
    }

    json = QJsonDocument::fromJson(filtersFileContents.toLatin1());
    filters = json.object();

    return json.isObject();
}

QString icsFilter::readFiltersFile(QString fileName, QString path)
{
    QFile fFile;
    QTextStream fData;
    QString result;

    if (fileName.length() > 0) {
        setFiltersFile(fileName, path);
    }

    fFile.setFileName(filtersFileName);
    if (fFile.exists()){
        fFile.open(QIODevice::ReadOnly | QIODevice::Text);
        fData.setDevice(&fFile);
        result = fData.readAll();
        fFile.close();
    }

    return result;
}

// reads the property name, value and parameters
int icsFilter::readProperty(QString line, QString &name,
                            QStringList &pNames, QStringList &pValues,
                            QString &value)
{
    int i, j;

    i = readPropertyName(line, name);
    if (i <= 0) {
        if (line.length() > 1) { // folded lines equal " "
            qDebug() << "No property name found:" << line;
        }
    } else {
        j = readPropertyParameters(line, i, pNames, pValues);
        if (j < 0) {
            j = i;
        }
        value = readPropertyValue(line, j);
        if (value.length() < 1) {
            qWarning() << "No property value found:" << line;
        }
    }

    //qDebug() << lineNr << name << value;
    return 0;
}

// returns the length of the name
int icsFilter::readPropertyName(QString line, QString &name)
{
    QRegExp propName;

    propName.setCaseSensitivity(Qt::CaseInsensitive);
    propName.setMinimal(false);
    propName.setPattern("^[a-z0-9-]+");
    propName.indexIn(line);

    name = propName.cap();

    //qDebug() << "luettu nimi:" << name;

    return name.length();
}

// returns the end position of the last parameter value
int icsFilter::readPropertyParameters(QString line, int position,
                                         QStringList &pNames,
                                         QStringList &pValues)
{
    QRegExp paramName, paramValue;
    QString values;
    int p1, p;

    p1 = position;
    p = position;
    pNames.clear();
    pValues.clear();
    paramName.setCaseSensitivity(Qt::CaseInsensitive);
    paramName.setMinimal(false);
    paramName.setPattern("^;([a-z0-9-]+)");
    // not quoted text must not contain '"', ";", ":", "," and controls except \t
    // quoted text must not contain '"' and controls except \t
    paramValue.setCaseSensitivity(Qt::CaseInsensitive);
    paramValue.setMinimal(false);
    paramValue.setPattern("^([^\";:,]+|\"[^\"]*\")");

    while (p > 0) {
        p = paramName.indexIn(line, p, QRegExp::CaretAtOffset);
        if (p >= 0) {
            pNames.append(paramName.cap(1));
            p += paramName.matchedLength();
            if (line.at(p) == '=') {
                p++;
            }
            p1 = p;
            while (p >= 0) {
                p = paramValue.indexIn(line, p, QRegExp::CaretAtOffset);
                p += paramValue.matchedLength();
                values.append(paramValue.cap(1));
                p1 = p;
                if (line.at(p) == ',') {
                    values.append(",");
                    p++;
                } else {
                    p = -1;
                }
            }
            pValues.append(values);
        }
    }

    return p1;
}

QString icsFilter::readPropertyValue(QString line, int position)
{
    QString result;
    int i;

    i = line.indexOf(":", position);
    if (i >= 0) {
        result = line.right(line.length() - i - 1);
    } else {
        result = "";
    }

    return result;
}

/*
// removes filters for calendar, calendar.component or calendar.component.property
QString icsFilter::removeFilter(QString label, QString idProperty,
                QString idValue, QString component, QString property)
{
    int iCal, iCom = 0, iPro = 0;
    QJsonArray calArr, comArr, proArr;
    QJsonObject calObj, comObj, proObj;
    QJsonValue jVal;

    if (filters.isEmpty()) {
        readFilters("");
    }

    if (label.isEmpty()) {
        iCal = listItemIndex(filters, keyCalendars, keyIdProperty, idProperty, keyIdVal, idValue);
        if (iCal < 0) {
            qWarning() << "Filters for calendar" << idProperty << "=" << idValue << "not found.";
        }
    } else {
        iCal = listItemIndex(filters, keyCalendars, keyName, label);
        if (iCal < 0) {
            qWarning() << "Filters for calendar" << label << "not found.";
        }
    }

    if (iCal >= 0) {
        calArr = filters.value(keyCalendars).toArray();
        if (component.isEmpty() && property.isEmpty()) {
            calArr.removeAt(iCal);
            qWarning() << "Removing calendar" << label << "or" << idProperty << "=" << idValue;
        } else {
            calObj = calArr.at(iCal).toObject();
            iCom = listItemIndex(calObj, keyFilters, keyComponent, component);
            if (iCom < 0) {
                qWarning() << "Remove filter failed: component" << component << "not found";
            } else {
                comArr = calObj.value(keyFilters).toArray();
                if (property.isEmpty()) {
                    comArr.removeAt(iCom);
                    qWarning() << "Removed filters for component" << component;
                } else {
                    comObj = comArr.at(iCom).toObject();
                    iPro = listItemIndex(comObj, keyProperties, keyProperty, property);
                    if (iPro < 0) {
                        qWarning() << "Remove filter failed: property" << property << "of component" << component << "not found";
                    } else {
                        proArr.removeAt(iPro);
                        qWarning() << "Removed filters for property" << property << "of component" << component;
                        comObj.insert(keyProperties, proArr);
                        comArr.replace(iCom, comObj);
                    }
                }
                if (iPro >= 0) { // if no errors
                    calObj.insert(keyFilters, comArr);
                }
            }
        }
        if (iCom >= 0 && iPro >= 0) { // if no errors
            filters.insert(keyCalendars, calArr);
        }
    }

    return storeFilter(false);
}
// */

void icsFilter::setFiltersFile(QString fileName, QString path)
{
    if (fileName.isEmpty()) {
        return;
    }
    if (fileName.indexOf('/') >= 0) {
        filtersFileName = fileName;
    } else {
        if (path.isEmpty()) {
            filtersFileName = filtersPath + fileName;
        } else {
            if (path.at(path.length()-1) != '/') {
                path.append('/');
            }
            filtersFileName = path + fileName;
        }
    }
    return;
}

// returns the number of lines in the component including "begin:"&"end:"
// or 0, if lineNr is not "begin:"
int icsFilter::skipComponent(int &lineNr)
{
    QRegExp beginCmp, endCmp, beginSub, endSub;
    QString component, line;
    int iN, row0, result;

    beginCmp.setCaseSensitivity(Qt::CaseInsensitive);
    beginCmp.setPattern("^begin:");
    endCmp.setCaseSensitivity(Qt::CaseInsensitive);

    row0 = lineNr;
    iN = modLines.length();
    line = modLines[lineNr];
    if (beginCmp.indexIn(line) >= 0) {
        lineNr++;
        component = line.right(line.length() - beginCmp.pattern().length() + 1); // '^'
        endCmp.setPattern("^end:" + component);
        while (lineNr < iN && endCmp.indexIn(modLines[lineNr]) < 0) {
            if (beginCmp.indexIn(modLines[lineNr]) >= 0) {
                lineNr = skipComponent(lineNr);
            }
            lineNr++;
        }
    }

    if (lineNr == row0) {
        result = 0;
    } else {
        result = lineNr - row0 + 1;
    }
    return result;
}

/*
QString icsFilter::storeFilter(bool includeNewFilter)
{
    QString fileContents;
    QJsonValue jVal;
    QJsonArray jArr;
    QFile fFile;
    QTextStream fData;
    QJsonDocument json;

    if (filters.isEmpty()) {
        if (!includeNewFilter) {
            return "";
        }
        readFilters("");
    }
    if (includeNewFilter) {
        jVal = filters.value(keyCalendars);
        if (jVal.isArray()) {
            jArr = jVal.toArray();
        }
        jArr.append(newFilter);
        filters.insert(keyCalendars, jArr);
    }
    json.fromVariant(filters);
    fileContents = json.toJson();

    fFile.setFileName(filtersFileName);
    fFile.open(QIODevice::WriteOnly | QIODevice::Text);
    fData.setDevice(&fFile);
    fData << fileContents;
    fFile.flush();
    fFile.close();

    if (fData.status() == QTextStream::WriteFailed) {
        qWarning() << "Writing json-file" << filtersFileName << "failed.";
        qDebug() << fFile.errorString();
    }

    return fileContents;
}
// */

// unfolds the lines, replaces the folds by space " "
// returns the number total number of unfolds
int icsFilter::unfoldLines()
{
    int result = 0;
    int i;
    i=0;
    while (i < modLines.length()) {
        result += unfoldLine(i);
        i++;
    }

    return result;
}

// unfolds line starting at lineNr, replaces the folds by space " "
// changes lineNr to the last fold line
// returns the number of unfolds
int icsFilter::unfoldLine(int &lineNr)
{
    QString nextLine, tmp;
    bool cont = true;
    int i = lineNr, result = 0;

    if (i >= modLines.length()) {
        return result;
    }

    tmp = modLines.at(i);
    while (i < modLines.length() - 2 && cont) {
        nextLine = modLines.at(i + 1);
        if (nextLine.at(0) == ' ' || nextLine.at(0) == '\t')  {
            tmp.append(nextLine.right(nextLine.length() - 1));
            modLines.replace(lineNr, tmp);
            modLines.replace(i+1, " ");
            i++;
            result++;
        } else {
            cont = false;
        }
    }

    lineNr = i;

    return result;
}

int icsFilter::overWriteFiltersFile(QString fileContents)
{
    QFile fFile;
    QTextStream fData;

    fFile.setFileName(filtersFileName);
    if (fFile.open(QIODevice::WriteOnly | QIODevice::Text)) {
        fData.setDevice(&fFile);
        fData << fileContents;
        fFile.close();
    }

    return fFile.error();
}
