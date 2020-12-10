unit Octopus.CommonAncestor;

interface

uses
  Generics.Collections,
  Octopus.Process;

type
  TCommonAncestorFinder = class
  private
    FTokens: TList<TToken>;
    function FindParent(Index: Integer): Integer;
    function GetAncestors(Index: Integer): TArray<Integer>;
    function CommonAncestor(A, B: Integer): Integer;
  public
    constructor Create(ATokens: TList<TToken>);
    destructor Destroy; override;
    function GetCommonAncestorToken(Indexes: TList<Integer>): TToken; overload;
    class function GetCommonAncestorToken(Tokens: TList<TToken>; Indexes: TList<Integer>): TToken; overload;
  end;

implementation

{ TCommonAncestorFinder }

function TCommonAncestorFinder.CommonAncestor(A, B: Integer): Integer;
var
  Ancestors: TArray<Integer>;
  I: Integer;
begin
  Ancestors := GetAncestors(A);
  repeat
    // Check if B if one of the A ancestors
    for I := 0 to Length(Ancestors) - 1 do
      if B = Ancestors[I] then
        Exit(B);
    B := FindParent(B);
  until B = -1;
  Result := -1;
end;

constructor TCommonAncestorFinder.Create(ATokens: TList<TToken>);
begin
  inherited Create;
  FTokens := ATokens;
end;

destructor TCommonAncestorFinder.Destroy;
begin

  inherited;
end;

function TCommonAncestorFinder.FindParent(Index: Integer): Integer;
var
  I: Integer;
begin
  // iterate from newest to oldest, it's more optimized as the chance to find
  // the parent is higher
  for I := Index - 1 downto 0 do
    if FTokens[Index].ParentId = FTokens[I].Id then
      Exit(I);

  // analyze remaining tokens, but it's unlikely we will find it here
  for I := Index + 1 to FTokens.Count - 1 do
    if FTokens[Index].ParentId = FTokens[I].Id then
      Exit(I);

  Result := -1;
end;

function TCommonAncestorFinder.GetCommonAncestorToken(Indexes: TList<Integer>): TToken;
var
  ParentIndex: Integer;
  I: Integer;
begin
  if (FTokens.Count = 0) or (Indexes.Count = 0) then Exit(nil);

  ParentIndex := Indexes[0];
  for I := 1 to Indexes.Count - 1 do
    ParentIndex := CommonAncestor(ParentIndex, Indexes[I]);
  if ParentIndex >= 0 then
    Result := FTokens[ParentIndex]
  else
    Result := nil;
end;

class function TCommonAncestorFinder.GetCommonAncestorToken(Tokens: TList<TToken>;
  Indexes: TList<Integer>): TToken;
var
  Finder: TCommonAncestorFinder;
begin
  Finder := TCommonAncestorFinder.Create(Tokens);
  try
    Result := Finder.GetCommonAncestorToken(Indexes);
  finally
    Finder.Free;
  end;
end;

function TCommonAncestorFinder.GetAncestors(Index: Integer): TArray<Integer>;
var
  Total: Integer;
begin
  SetLength(Result, FTokens.Count);
  Total := 0;
  repeat
    Result[Total] := Index;
    Index := FindParent(Index);
    Inc(Total);
  until Index = -1;
  SetLength(Result, Total);
end;

end.
