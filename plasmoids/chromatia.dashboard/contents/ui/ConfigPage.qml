// Base of every Chromatia Settings page. Plasma hands each page every setting plus its default,
// so all of them are declared once here (otherwise each page logs "does not have a property called cfg_…").
import org.kde.kcmutils as KCM

KCM.SimpleKCM {
    property string cfg_accentColor; property string cfg_accentColorDefault
    property string cfg_notes; property string cfg_notesDefault
    property int cfg_lastTab; property int cfg_lastTabDefault
    property string cfg_aliases; property string cfg_aliasesDefault
    property string cfg_hiddenOutputs; property string cfg_hiddenOutputsDefault
    property string cfg_hiddenInputs; property string cfg_hiddenInputsDefault
    property string cfg_deviceNames; property string cfg_deviceNamesDefault
    property bool cfg_systemAccent; property bool cfg_systemAccentDefault
    property bool cfg_appColors; property bool cfg_appColorsDefault
    property bool cfg_chromatiaPopups; property bool cfg_chromatiaPopupsDefault
    property int cfg_popupSeconds; property int cfg_popupSecondsDefault
    property bool cfg_hideInFullscreen; property bool cfg_hideInFullscreenDefault
    property bool cfg_openNotificationsFirst; property bool cfg_openNotificationsFirstDefault
    property int cfg_accentMode; property int cfg_accentModeDefault
    property string cfg_fixedAccent; property string cfg_fixedAccentDefault
}
