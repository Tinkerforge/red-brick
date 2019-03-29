Imports Tinkerforge

Module TestBrickletIndustrialDualRelay
    Const HOST As String = "localhost"
    Const PORT As Integer = 4223
    Const UID As String = "xyz" ' Change to your UID

    Sub Main()
        Dim ipcon As New IPConnection() ' Create IP connection
        Dim dr As New BrickletIndustrialDualRelay(UID, ipcon) ' Create device object

        ipcon.Connect(HOST, PORT) ' Connect to brickd
        ' Don't use device before ipcon is connected

        ' Turn both relays off and on
        dr.SetValue(False, False)
        System.Threading.Thread.Sleep(1000)
        dr.SetValue(True, True)

        ipcon.Disconnect()
    End Sub
End Module
