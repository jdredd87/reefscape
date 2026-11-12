' One LabelList with header rows (LIGHTING / CLOCK / ANIMALS) and option rows that show a
' checkbox or radio-button icon. The list handles the remote by itself (up/down/OK); it
' deliberately has no key handler of its own, because Roku does not allow screensavers to use one.
' Every change is saved immediately, so Back can simply close the screen.
sub init()
    m.list = m.top.FindNode("list")
    m.modes = lightModes()
    m.clocks = clockModes()
    m.animals = animalList()

    ' rows: { kind: "header" | "light" | "clock" | "animal", key }
    m.rows = []
    root = CreateObject("roSGNode", "ContentNode")
    addRows(root, "LIGHTING", "light", m.modes)
    addRows(root, "CLOCK", "clock", m.clocks)
    addRows(root, "ANIMALS", "animal", m.animals)
    m.list.content = root
    m.list.ObserveField("itemSelected", "onSelected")
end sub

sub addRows(root as object, title as string, kind as string, items as object)
    h = root.CreateChild("ContentNode")
    h.title = title
    m.rows.Push({ kind: "header", key: "" })
    for each it in items
        node = root.CreateChild("ContentNode")
        node.title = it[1]
        m.rows.Push({ kind: kind, key: it[0] })
    end for
end sub

' Load the saved settings into the list and take focus
function open(params as object) as boolean
    m.st = loadSettings()
    refresh()
    m.list.jumpToItem = 1
    m.list.SetFocus(true)
    return true
end function

' set each row's icon from the current settings
sub refresh()
    for i = 0 to m.rows.Count() - 1
        r = m.rows[i]
        icon = ""
        if r.kind = "light" then
            icon = "radio_off"
            if r.key = m.st.light then icon = "radio_on"
        else if r.kind = "clock" then
            icon = "radio_off"
            if r.key = m.st.clock then icon = "radio_on"
        else if r.kind = "animal" then
            icon = "check_on"
            if m.st.off[r.key] <> invalid then icon = "check_off"
        end if
        node = m.list.content.getChild(i)
        if icon = "" then
            node.HDListItemIconUrl = ""
            node.HDListItemIconSelectedUrl = ""
        else
            node.HDListItemIconUrl = "pkg:/images/ocean/ui_" + icon + ".png"
            node.HDListItemIconSelectedUrl = "pkg:/images/ocean/ui_" + icon + "_f.png"
        end if
    end for
end sub

sub onSelected()
    r = m.rows[m.list.itemSelected]
    if r.kind = "light" then
        m.st.light = r.key
    else if r.kind = "clock" then
        m.st.clock = r.key
    else if r.kind = "animal" then
        if m.st.off[r.key] <> invalid then m.st.off.Delete(r.key) else m.st.off[r.key] = true
    else
        return
    end if
    refresh()
    saveSettings(m.st)
end sub
