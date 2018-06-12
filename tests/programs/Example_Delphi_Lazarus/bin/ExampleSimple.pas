program ExampleSimple;

{$ifdef MSWINDOWS}{$apptype CONSOLE}{$endif}
{$ifdef FPC}{$mode OBJFPC}{$H+}{$endif}

uses
  SysUtils, IPConnection, BrickletDualRelay;

type
  TExample = class
  private
    ipcon: TIPConnection;
    dr: TBrickletDualRelay;
  public
    procedure Execute;
  end;

const
  HOST = 'localhost';
  PORT = 4223;
  UID = 'xyz'; { Change to your UID }

var
  e: TExample;

procedure TExample.Execute;
var i: integer;
begin
  { Create IP connection }
  ipcon := TIPConnection.Create;

  { Create device object }
  dr := TBrickletDualRelay.Create(UID, ipcon);

  { Connect to brickd }
  ipcon.Connect(HOST, PORT);
  { Don't use device before ipcon is connected }

  { Turn relays alternating on/off for 10 times with 1 second delay }
  for i := 0 to 9 do begin
    Sleep(1000);

    if (i mod 2 = 1) then begin
      dr.SetState(true, false);
    end
    else begin
      dr.SetState(false, true);
    end;
  end;

  ipcon.Destroy; { Calls ipcon.Disconnect internally }
end;

begin
  e := TExample.Create;
  e.Execute;
  e.Destroy;
end.
