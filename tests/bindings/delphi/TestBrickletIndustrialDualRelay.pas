program TestBrickletIndustrialDualRelay;

{$ifdef MSWINDOWS}{$apptype CONSOLE}{$endif}
{$ifdef FPC}{$mode OBJFPC}{$H+}{$endif}

uses
  SysUtils, IPConnection, BrickletIndustrialDualRelay;

type
  TTBIDR = class
  private
    ipcon: TIPConnection;
    dr: TBrickletIndustrialDualRelay;
  public
    procedure Execute;
  end;

const
  HOST = 'localhost';
  PORT = 4223;
  UID = 'xyz'; { Change to your UID }

var
  e: TTBIDR;

procedure TTBIDR.Execute;
begin
  { Create IP connection }
  ipcon := TIPConnection.Create;

  { Create device object }
  dr := TBrickletIndustrialDualRelay.Create(UID, ipcon);

  { Connect to brickd }
  ipcon.Connect(HOST, PORT);
  { Don't use device before ipcon is connected }

  { Turn both relays off and on }
  dr.SetValue(false, false);
  Sleep(1000);
  dr.SetValue(true, true);

  ipcon.Destroy; { Calls ipcon.Disconnect internally }
end;

begin
  e := TTBIDR.Create;
  e.Execute;
  e.Destroy;
end.
