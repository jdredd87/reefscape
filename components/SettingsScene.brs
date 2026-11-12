sub init()
    m.panel = m.top.FindNode("panel")
    m.panel.ObserveField("done", "onPanelDone")
    m.panel.callFunc("open", {})
end sub

sub onPanelDone()
    m.top.done = true
end sub
