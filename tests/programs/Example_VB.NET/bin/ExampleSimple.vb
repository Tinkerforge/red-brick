Imports Tinkerforge

Module ExampleSimple
    Const HOST As String = "localhost"
    Const PORT As Integer = 4223
    Const UID As String = "xyz" ' Change to your UID

    Sub Main()
        Dim ipcon As New IPConnection() ' Create IP connection
        Dim dr As New BrickletDualRelay(UID, ipcon) ' Create device object

        ipcon.Connect(HOST, PORT) ' Connect to brickd
        ' Don't use device before ipcon is connected

        ' Turn relays alternating on/off for 10 times with 1 second delay
        Dim i As Integer

        For i = 1 To 10
            System.Threading.Thread.Sleep(1000)

            If i Mod 2 = 0 Then
                dr.SetState(True, False)
            Else
                dr.SetState(False, True)
            End If
        Next i

        ipcon.Disconnect()
    End Sub
End Module
