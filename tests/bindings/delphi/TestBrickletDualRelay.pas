program TestBrickletDualRelay;

{$ifdef MSWINDOWS}{$apptype CONSOLE}{$endif}
{$ifdef FPC}{$mode OBJFPC}{$H+}{$endif}

uses
  SysUtils, IPConnection, BrickletDualRelay;

type
  TTBDR = class
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
  e: TTBDR;

procedure TTBDR.Execute;
var i: integer;
begin
  { Create IP connection }
  ipcon := TIPConnection.Create;

  { Create device object }
  dr := TBrickletDualRelay.Create(UID, ipcon);

  { Connect to brickd }
  ipcon.Connect(HOST, PORT);
  { Don't use device before ipcon is connected }

  { Turn both relays off and on }
  dr.SetState(false, false);
  Sleep(1000);
  dr.SetState(true, true);

  ipcon.Destroy; { Calls ipcon.Disconnect internally }
end;

begin
  e := TTBDR.Create;
  e.Execute;
  e.Destroy;
end.
