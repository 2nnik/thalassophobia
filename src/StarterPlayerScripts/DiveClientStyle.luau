local UI = {}
local function rgb(r,g,b) return Color3.fromRGB(r,g,b) end
UI.c = {
    sea=rgb(7,21,26), surface=rgb(11,31,37), panel=rgb(14,39,45),
    raised=rgb(22,54,60), line=rgb(53,91,96), grid=rgb(25,61,68),
    white=rgb(230,240,229), soft=rgb(161,192,188), green=rgb(114,223,183),
    orange=rgb(255,167,103), red=rgb(255,124,105), black=rgb(4,14,18)
}
UI.body=Enum.Font.Gotham
UI.bold=Enum.Font.GothamBold
UI.mono=Enum.Font.Code
function UI.make(class,parent,properties)
    local object=Instance.new(class)
    for key,value in pairs(properties or {}) do object[key]=value end
    object.Parent=parent
    return object
end
function UI.frame(parent,color,pos,size,alpha)
    return UI.make("Frame",parent,{BorderSizePixel=0,BackgroundColor3=color,BackgroundTransparency=alpha or 0,
        Position=pos or UDim2.new(),Size=size or UDim2.fromScale(1,1)})
end
function UI.label(parent,value,size,col,font,pos,dim,align)
    return UI.make("TextLabel",parent,{BackgroundTransparency=1,Text=value,TextSize=size,Font=font or UI.body,
        TextColor3=col or UI.c.white,TextXAlignment=align or Enum.TextXAlignment.Left,TextYAlignment=Enum.TextYAlignment.Center,
        Position=pos or UDim2.new(),Size=dim or UDim2.fromScale(1,1),TextTruncate=Enum.TextTruncate.AtEnd})
end
function UI.edge(object,color)
    return UI.make("UIStroke",object,{ApplyStrokeMode=Enum.ApplyStrokeMode.Border,Thickness=1,Color=color or UI.c.line})
end
function UI.button(parent,caption,id,background,foreground,callback)
    local btn=UI.make("TextButton",parent,{
        Name=id,BackgroundColor3=background,BorderSizePixel=0,Text=caption,TextColor3=foreground,
        TextSize=15,Font=UI.bold,AutoButtonColor=true,Selectable=true
    })
    btn.Activated:Connect(callback)
    return btn
end
function UI.line(parent,x1,y1,x2,y2,color,width)
    local length=Vector2.new(x2-x1,y2-y1).Magnitude
    local f=UI.frame(parent,color,UDim2.fromOffset((x1+x2)/2,(y1+y2)/2),UDim2.fromOffset(length,width or 1))
    f.AnchorPoint=Vector2.new(.5,.5)
    f.Rotation=math.deg(math.atan2(y2-y1,x2-x1))
    return f
end
return UI
