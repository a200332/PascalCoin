unit UUserInterface;

{ Copyright (c) 2018 by Herman Schoenfeld

  Distributed under the MIT software license, see the accompanying file LICENSE
  or visit http://www.opensource.org/licenses/mit-license.php.

  This unit is a part of the PascalCoin Project, an infinitely scalable
  cryptocurrency. Find us here:
  Web: https://www.pascalcoin.org
  Source: https://github.com/PascalCoin/PascalCoin

  Acknowledgements:
  - Albert Molina: portions of code copied from https://github.com/PascalCoin/PascalCoin/blob/Releases/2.1.6/Units/Forms/UFRMWallet.pas

  THIS LICENSE HEADER MUST NOT BE REMOVED.
}

{$mode delphi}

interface

{$I ..\config.inc}

uses
  SysUtils, Classes, Forms, Controls, {$IFDEF WINDOWS}Windows,{$ENDIF} ExtCtrls,
  Dialogs, LCLType,
  UCommon, UCommon.UI,
  UBlockChain, UAccounts, UNode, UWallet, UConst, UFolderHelper, UGridUtils, URPC, UPoolMining,
  ULog, UThread, UNetProtocol, UCrypto, UBaseTypes,
  UFRMMainForm, UCTRLSyncronization, UFRMAccountExplorer, UFRMOperationExplorer, UFRMPendingOperations, UFRMOperation,
  UFRMLogs, UFRMMessages, UFRMNodes, UFRMBlockExplorer, UFRMWalletKeys, UPCOrderedLists {$IFDEF TESTNET},UFRMRandomOperations, UAccountKeyStorage{$ENDIF};

type
  { Forward Declarations }

  TLoadDatabaseThread = class;

  { TUserInterfaceState }
  TUserInterfaceState = (uisLoading, uisLoaded, uisDiscoveringPeers, uisSyncronizingBlockchain, uisActive, uisIsolated, uisDisconnected, uisError);

  { TUserInterface }

  TUserInterface = class
    private
      // Root-form
      FUILock : TPCCriticalSection; static;

      // Subforms
      FAccountExplorer : TFRMAccountExplorer; static;
      FPendingOperationForm : TFRMPendingOperations; static;
      FOperationsExplorerForm : TFRMOperationExplorer; static;
      FBlockExplorerForm : TFRMBlockExplorer; static;
      FLogsForm : TFRMLogs; static;
      FNodesForm : TFRMNodes; static;
      FMessagesForm : TFRMMessages; static;

      // Components
      FRPCServer : TRPCServer; static;
      FPoolMiningServer : TPoolMiningServer; static;

      // Local fields
      FStarted : boolean; static;
      FMainForm : TFRMMainForm; static;
      FIsActivated : Boolean; static;
      FUpdating : Boolean; static;
      FLog : TLog; static;
      FNode : TNode; static;
      FTimerUpdateStatus: TTimer; static;
      FTrayIcon: TTrayIcon; static;
      FNodeNotifyEvents : TNodeNotifyEvents; static;
      FStatusBar0Text : AnsiString; static;
      FStatusBar1Text : AnsiString; static;
      FStatusBar2Text : AnsiString; static;
      FMessagesNotificationText : AnsiString; static;
      FDisplayedStartupSyncDialog : boolean; static;
      FAppStarted : TNotifyManyEvent; static;
      FLoading : TProgressNotifyMany; static;
      FLoaded : TNotifyManyEvent; static;
      FStateChanged : TNotifyManyEvent; static;
      FAccountsChanged : TNotifyManyEvent; static;
      FBlocksChanged : TNotifyManyEvent; static;
      FReceivedHelloMessage : TNotifyManyEvent; static;
      FNodeMessageEvent : TNodeMessageManyEvent; static;
      FNetStatisticsChanged : TNotifyManyEvent; static;
      FNetConnectionsUpdated : TNotifyManyEvent; static;
      FNetNodeServersUpdated : TNotifyManyEvent; static;
      FNetBlackListUpdated : TNotifyManyEvent; static;
      FMiningServerNewBlockFound : TNotifyManyEvent; static;
      FUIRefreshTimer : TNotifyManyEvent; static;
      FState : TUserInterfaceState; static;
      FStateText : String; static;

      // Getters/Setters
      class function GetEnabled : boolean; static;
      class procedure SetEnabled(ABool: boolean); static;
      class procedure SetState(AState : TUserInterfaceState); static;

      // Handlers
      class procedure OnSettingsChanged(Sender: TObject);
      class procedure OnLoaded(Sender: TObject);
      class procedure OnUITimerRefresh(Sender: TObject);
      class procedure OnReceivedHelloMessage(Sender: TObject);
      class procedure OnMiningServerNewBlockFound(Sender: TObject);
      class procedure OnSubFormDestroyed(Sender: TObject);
      class procedure OnTrayIconDblClick(Sender: TObject);

      // Aux
      class procedure NotifyLoadedEvent(Sender: TObject);
      class procedure NotifyLoadingEvent(Sender: TObject; const message: AnsiString; curPos, totalCount: Int64);
      class procedure NotifyStateChanged(Sender: TObject);
      class procedure NotifyAccountsChangedEvent(Sender: TObject);
      class procedure NotifyBlocksChangedEvent(Sender: TObject);
      class procedure NotifyReceivedHelloMessageEvent(Sender: TObject);
      class procedure NotifyNodeMessageEventEvent(NetConnection: TNetConnection; MessageData: String);
      class procedure NotifyNetStatisticsChangedEvent(Sender: TObject);
      class procedure NotifyNetConnectionsUpdatedEvent(Sender: TObject);
      class procedure NotifyNetNodeServersUpdatedEvent(Sender: TObject);
      class procedure NotifyNetBlackListUpdatedEvent(Sender: TObject);
      class procedure NotifyMiningServerNewBlockFoundEvent(Sender: TObject);
      class procedure NotifyUIRefreshTimerEvent(Sender: TObject);
    public
      // Properties
      class property Enabled : boolean read GetEnabled write SetEnabled;
      class property Started : boolean read FStarted;
      class property State : TUserInterfaceState read FState write SetState;
      class property StateText : string read FStateText;
      class property Node : TNode read FNode;
      class property Log : TLog read FLog;
      class property PoolMiningServer : TPoolMiningServer read FPoolMiningServer;

      // Events
      class property AppStarted : TNotifyManyEvent read FAppStarted;
      class property Loading : TProgressNotifyMany read FLoading;
      class property Loaded : TNotifyManyEvent read FLoaded;
      class property StateChanged : TNotifyManyEvent read FStateChanged;
      class property AccountsChanged : TNotifyManyEvent read FAccountsChanged;
      class property BlocksChanged : TNotifyManyEvent read FBlocksChanged;
      class property ReceivedHelloMessage : TNotifyManyEvent read FReceivedHelloMessage;
      class property NodeMessageEvent : TNodeMessageManyEvent read FNodeMessageEvent;
      class property NetStatisticsChanged : TNotifyManyEvent read FNetStatisticsChanged;
      class property NetConnectionsUpdated : TNotifyManyEvent read FNetConnectionsUpdated;
      class property NetNodeServersUpdated : TNotifyManyEvent read FNetNodeServersUpdated;
      class property NetBlackListUpdated : TNotifyManyEvent read FNetBlackListUpdated;
      class property MiningServerNewBlockFound : TNotifyManyEvent read FMiningServerNewBlockFound;
      class property UIRefreshTimer : TNotifyManyEvent read FUIRefreshTimer;

      // Methods
      class procedure StartApplication(mainForm : TForm);
      class procedure ExitApplication;
      class procedure RunInBackground;
      class procedure RunInForeground;
      class procedure CheckNodeIsReady;
      {$IFDEF TESTNET}
      {$IFDEF TESTING_NO_POW_CHECK}
      class procedure CreateABlock;
      {$ENDIF}
      {$ENDIF}

      // Show Dialogs
      class procedure ShowSendDialog(const AAccounts : array of Cardinal);
      class procedure ShowChangeKeyDialog(const AAccounts : array of Cardinal);
      class procedure ShowSellAccountsDialog(const AAccounts : array of Cardinal);
      class procedure ShowDelistAccountsDialog(const AAccounts : array of Cardinal);
      class procedure ShowChangeAccountInfoDialog(const AAccounts : array of Cardinal);
      class procedure ShowBuyAccountDialog(const AAccounts : array of Cardinal);
      class procedure ShowAboutBox(parentForm : TForm);
      class procedure ShowOptionsDialog(parentForm: TForm);
      class procedure ShowAccountInfoDialog(parentForm: TForm; const account : Cardinal); overload;
      class procedure ShowAccountInfoDialog(parentForm: TForm; const account : TAccount); overload;
      class procedure ShowOperationInfoDialog(parentForm: TForm; const ophash : AnsiString); overload;
      class procedure ShowOperationInfoDialog(parentForm: TForm; const operation : TOperationResume); overload;
      class procedure ShowAccountOperationInfoDialog(parentForm: TForm; const account : TAccount; const operation : TOperationResume); overload;
      class procedure ShowNewOperationDialog(parentForm : TForm; accounts : TOrderedCardinalList; defaultFee : Cardinal);
      class procedure ShowSeedNodesDialog(parentForm : TForm);
      class procedure ShowPrivateKeysDialog(parentForm: TForm);
      class procedure ShowMemoText(parentForm: TForm; const ATitle : AnsiString; text : utf8string); overload;
      class procedure ShowMemoText(parentForm: TForm; const ATitle : AnsiString; text : TStrings); overload;
      class procedure UnlockWallet(parentForm: TForm);
      class procedure ChangeWalletPassword(parentForm: TForm);
      {$IFDEF TESTNET}
      class procedure ShowPublicKeysDialog(parentForm: TForm);
      class procedure ShowRandomOperationsDialog(parentForm: TForm);
      {$ENDIF}
      class procedure ShowInfo(parentForm : TForm; const ACaption, APrompt : String);
      class procedure ShowWarning(parentForm : TForm; const ACaption, APrompt : String);
      class procedure ShowError(parentForm : TForm; const ACaption, APrompt : String);
      class function AskQuestion(parentForm: TForm; AType:TMsgDlgType; const ACaption, APrompt : String; buttons: TMsgDlgButtons) : TMsgDlgBtn;
      class function AskEnterString(parentForm: TForm; const ACaption, APrompt : String; var Value : String) : Boolean;
      class function AskEnterProtectedString(parentForm: TForm; const ACaption, APrompt : String; var Value : String) : Boolean;

      // Show sub-forms
      class procedure ShowAccountExplorer;
      class procedure ShowBlockExplorer;
      class procedure ShowOperationsExplorer;
      class procedure ShowPendingOperations;
      class procedure ShowMessagesForm;
      class procedure ShowNodesForm;
      class procedure ShowLogsForm;
      class procedure ShowWallet;
      class procedure ShowSyncDialog;
  end;

  { TLoadSafeBoxThread }

  TLoadDatabaseThread = Class(TPCThread)
  protected
    procedure OnProgressNotify(sender : TObject; const message : AnsiString; curPos, totalCount : Int64);
    procedure OnLoaded;
    procedure BCExecute; override;
  End;

  { Exceptions }

  EUserInterface = class(Exception);

implementation

uses
  UFRMAbout, UFRMNodesIp, UFRMPascalCoinWalletConfig, UFRMPayloadDecoder, UFRMMemoText,
  UOpenSSL, UFileStorage, UTime, USettings, UCoreUtils, UMemory,
  UWIZOperation, UWIZSendPASC, UWIZChangeKey, UWIZEnlistAccountForSale, UWIZDelistAccountFromSale, UWIZChangeAccountInfo, UWIZBuyAccount, UCoreObjects;

{%region UI Lifecyle}

class procedure TUserInterface.StartApplication(mainForm : TForm);
Var ips : AnsiString;
  nsarr : TNodeServerAddressArray;
begin
  inherited;
  if FIsActivated then exit;
  FIsActivated := true;
  try
    // Create UI lock
    FUILock := TPCCriticalSection.Create('TUserInterface.UILock');

    // Initialise field defaults
    FIsActivated := false;
    FStarted := false;
    FRPCServer := Nil;
    FNode := Nil;
    FPoolMiningServer := Nil;
    FNodeNotifyEvents := nil;
    FUpdating := false;
    FStatusBar0Text := '';
    FStatusBar1Text := '';
    FStatusBar2Text := '';
    FMessagesNotificationText := '';

    // Create root form and dependent components
    FMainForm := mainForm as TFRMMainForm;
    FMainForm.CloseAction := caNone;     // wallet is destroyed on ExitApplication
    if (FMainForm = nil)
      then raise Exception.Create('Main form is not TWallet');

    FTrayIcon := TTrayIcon.Create(FMainForm);
    FTrayIcon.OnDblClick := OnTrayIconDblClick;
    {$IFNDEF LCLCarbon}
    FTrayIcon.Visible := true;
    {$ENDIF}
    FTrayIcon.Hint := FMainForm.Caption;
    FTrayIcon.BalloonTitle := 'Restoring the window.';
    FTrayIcon.BalloonHint := 'Double click the system tray icon to restore Pascal Coin';
    FTrayIcon.BalloonFlags := bfInfo;
    {$IFNDEF LCLCarbon}
    FTrayIcon.Show;
    {$ENDIF}
    FTimerUpdateStatus := TTimer.Create(FMainForm);
    FTimerUpdateStatus.Enabled := false;
    FDisplayedStartupSyncDialog:=false;

    // Create log
    FLog := TLog.Create(nil); // independent component
    FLog.SaveTypes := [];

    // Create data directories
    If Not ForceDirectories(TFolderHelper.GetPascalCoinDataFolder) then
      raise Exception.Create('Cannot create dir: '+TFolderHelper.GetPascalCoinDataFolder);

    // Load settings
    TSettings.Load;
    TSettings.OnChanged.Add(OnSettingsChanged);

    // Open Wallet
    TWallet.Load;

    // Load peer list
    ips := TSettings.TryConnectOnlyWithThisFixedServers;
    TNode.DecodeIpStringToNodeServerAddressArray(ips,nsarr);
    TNetData.NetData.DiscoverFixedServersOnly(nsarr);
    setlength(nsarr,0);

    // Start Node
    FNode := TNode.Node;
    FNode.NetServer.Port := TSettings.InternetServerPort;
    FNode.PeerCache := TSettings.PeerCache+';'+CT_Discover_IPs;
    FReceivedHelloMessage.Add(OnReceivedHelloMessage);

    // Subscribe to Node events (TODO refactor with FNotifyEvents)
    FNodeNotifyEvents := TNodeNotifyEvents.Create(FMainForm);
    FNodeNotifyEvents.OnBlocksChanged := NotifyBlocksChangedEvent;
    FNodeNotifyEvents.OnNodeMessageEvent :=  NotifyNodeMessageEventEvent;

    // Start RPC server
    FRPCServer := TRPCServer.Create;
    FRPCServer.WalletKeys := TWallet.Keys;
    FRPCServer.Active := TSettings.RpcPortEnabled;
    FRPCServer.ValidIPs := TSettings.RpcAllowedIPs;
    TWallet.Keys.SafeBox := FNode.Bank.SafeBox;

    // Initialise Database
    FNode.Bank.StorageClass := TFileStorage;
    TFileStorage(FNode.Bank.Storage).DatabaseFolder := TFolderHelper.GetPascalCoinDataFolder+PathDelim+'Data';
    TFileStorage(FNode.Bank.Storage).Initialize;

    // Reading database
    State := uisLoading;
    FLoaded.Add(OnLoaded);
    TLoadDatabaseThread.Create(false).FreeOnTerminate := true;

    // Init
    TNetData.NetData.OnReceivedHelloMessage := NotifyReceivedHelloMessageEvent;
    TNetData.NetData.OnStatisticsChanged := NotifyNetStatisticsChangedEvent;
    TNetData.NetData.OnNetConnectionsUpdated := NotifyNetConnectionsUpdatedEvent;
    TNetData.NetData.OnNodeServersUpdated := NotifyNetNodeServersUpdatedEvent;
    TNetData.NetData.OnBlackListUpdated := NotifyNetBlackListUpdatedEvent;

    // Start refresh timer
    FTimerUpdateStatus.OnTimer := NotifyUIRefreshTimerEvent;
    FTimerUpdateStatus.Interval := 1000;
    FTimerUpdateStatus.Enabled := true;
    FUIRefreshTimer.Add(OnUITimerRefresh); //TODO: move to initialisation?

    // open the sync dialog
    FStarted := true;
    FAppStarted.Invoke(nil);
  Except
    On E:Exception do begin
      E.Message := 'An error occurred during initialization. Application cannot continue:'+#10+#10+E.Message+#10+#10+'Application will close...';
      Application.MessageBox(PChar(E.Message),PChar(Application.Title),MB_ICONERROR+MB_OK);
      Halt;
    end;
  end;

  // Notify accounts changed
  NotifyAccountsChangedEvent(FMainForm);

  // Show sync dialog
  ShowSyncDialog;

  // Final loading sequence
  TSettings.RunCount := TSettings.RunCount + 1;
  if TSettings.RunCount = 1 then begin
    ShowAboutBox(nil);
  end;
  TSettings.Save;
end;

class procedure TUserInterface.ExitApplication;
var
  i : Integer;
  step : String;
begin
  // Exit application
  TLog.NewLog(ltinfo,Classname,'Quit Application - START');
  Try
    step := 'Deregistering events';
    TSettings.OnChanged.Remove(OnSettingsChanged);
    FUIRefreshTimer.Remove(OnUITimerRefresh);
    FReceivedHelloMessage.Remove(OnReceivedHelloMessage);
    FLoaded.Remove(OnLoaded);
    FUIRefreshTimer.Remove(OnUITimerRefresh);

    step := 'Saving Settings';
    TSettings.Save;

    // Destroys root form, non-modal forms and all their attached components
    step := 'Destroying UI graph';
    FMainForm.Destroy;
    FMainForm := nil;  // destroyed by FWallet
    FAccountExplorer := nil;  // destroyed by FWallet
    FPendingOperationForm := nil;  // destroyed by FWallet
    FOperationsExplorerForm := nil;  // destroyed by FWallet
    FBlockExplorerForm := nil;  // destroyed by FWallet
    FLogsForm := nil;  // destroyed by FWallet
    FNodesForm := nil;  // destroyed by FWallet
    FMessagesForm := nil;  // destroyed by FWallet
    FTrayIcon := nil; // destroyed by FWallet
    FNodeNotifyEvents := nil; // destroyed by FWallet

    step := 'Destroying components';
    FreeAndNil(FRPCServer);
    FreeAndNil(FPoolMiningServer);

    step := 'Assigning nil events';
    FLog.OnNewLog :=Nil;

    TNetData.NetData.OnReceivedHelloMessage := Nil;
    TNetData.NetData.OnStatisticsChanged := Nil;
    TNetData.NetData.OnNetConnectionsUpdated := Nil;
    TNetData.NetData.OnNodeServersUpdated := Nil;
    TNetData.NetData.OnBlackListUpdated := Nil;

    step := 'Assigning Nil to TNetData';
    TNetData.NetData.OnReceivedHelloMessage := Nil;
    TNetData.NetData.OnStatisticsChanged := Nil;

    step := 'Desactivating Node';
    TNode.Node.NetServer.Active := false;
    FNode := Nil;

    // Destroy NetData
    TNetData.NetData.Free;

    step := 'Processing messages 1';
    Application.ProcessMessages;

    step := 'Destroying Node';
    TNode.Node.Free;

    step := 'Processing messages 2';
    Application.ProcessMessages;

    FreeAndNil(FUILock);
  Except
    On E:Exception do begin
      TLog.NewLog(lterror,Classname,'Error quiting application step: '+step+' Errors ('+E.ClassName+'): ' +E.Message);
    end;
  End;
  TLog.NewLog(ltinfo,Classname,'Error quiting application - END');
  FreeAndNil(FLog);
  Application.Terminate;
end;

class procedure TUserInterface.RunInBackground;
begin
  FMainForm.Hide();
  FMainForm.WindowState := wsMinimized;
  FTimerUpdateStatus.Enabled := false;
  FTrayIcon.Visible := True;
  FTrayIcon.ShowBalloonHint;
end;

class procedure TUserInterface.RunInForeground;
begin
  FTrayIcon.Visible := False;
  FTimerUpdateStatus.Enabled := true;
  FMainForm.Show();
  FMainForm.WindowState := wsNormal;
  Application.BringToFront();
end;

{%endregion}

{%region UI Handlers }

class procedure TUserInterface.OnTrayIconDblClick(Sender: TObject);
begin
  RunInForeground;
end;

class procedure TUserInterface.OnSubFormDestroyed(Sender: TObject);
begin
  FUILock.Acquire;
  try
    if Sender = FAccountExplorer then
      FAccountExplorer := nil // form free's on close
    else if Sender = FPendingOperationForm then
      FPendingOperationForm := nil // form free's on close
    else if Sender = FOperationsExplorerForm then
      FOperationsExplorerForm := nil // form free's on close
    else if Sender = FBlockExplorerForm then
      FBlockExplorerForm := nil // form free's on close
    else if Sender = FLogsForm then
      FLogsForm := nil // form free's on close
    else if Sender = FNodesForm then
      FNodesForm := nil // form free's on close
    else if Sender = FMessagesForm then
      FMessagesForm := nil
    else
      raise Exception.Create('Internal Error: [NotifySubFormDestroyed] encountered an unknown sub-form instance');
  finally
    FUILock.Release;
  end;
end;

class procedure TUserInterface.OnLoaded(Sender: TObject);
begin
  FPoolMiningServer := TPoolMiningServer.Create;
  FPoolMiningServer.Port := TSettings.MinerServerRpcPort;
  FPoolMiningServer.MinerAccountKey := TWallet.MiningKey;
  FPoolMiningServer.MinerPayload := TEncoding.ANSI.GetBytes(TSettings.MinerName);
  FNode.Operations.AccountKey := TWallet.MiningKey;
  FPoolMiningServer.Active := TSettings.MinerServerRpcActive;
  FPoolMiningServer.OnMiningServerNewBlockFound := NotifyMiningServerNewBlockFoundEvent;
  State := uisLoaded;
  ShowWallet;
end;

class procedure TUserInterface.OnUITimerRefresh(Sender: TObject);
var
  LActive, LDiscoveringPeers, LGettingNewBlockchain, LRemoteHasBiggerBlock, LNoConnections : boolean;
  LState : TUserInterfaceState;
  LLocalTip, LRemoteTip : Cardinal;
  LMsg : AnsiString;
begin
  LState := FState;
  LActive := FNode.NetServer.Active;
  LDiscoveringPeers := TNetData.NetData.IsDiscoveringServers;
  LGettingNewBlockchain := TNetData.NetData.IsGettingNewBlockChainFromClient(LMsg);
  LLocalTip := Node.Bank.BlocksCount;
  LRemoteTip := TNetData.NetData.MaxRemoteOperationBlock.block;
  LRemoteHasBiggerBlock := LRemoteTip > LLocalTip;
  LNoConnections := TNetData.NetData.NetStatistics.ActiveConnections = 0;

  if LActive then begin
    if LDiscoveringPeers then
      LState := uisDiscoveringPeers;

    if LGettingNewBlockchain OR LRemoteHasBiggerBlock then
      LState := uisSyncronizingBlockchain;

    if LNoConnections then
      LState := uisIsolated;

    if (NOT LDiscoveringPeers) AND (NOT LGettingNewBlockchain) AND (NOT LRemoteHasBiggerBlock) AND (NOT LNoConnections) then
      LState := uisActive;

  end else LState := uisDisconnected;
  State := LState;
end;

class procedure TUserInterface.OnSettingsChanged(Sender: TObject);
Var wa : Boolean;
  i : Integer;
begin
  if TSettings.SaveLogFiles then begin
    if TSettings.SaveDebugLogs then
      FLog.SaveTypes := CT_TLogTypes_ALL
    else
      FLog.SaveTypes := CT_TLogTypes_DEFAULT;
    FLog.FileName := TFolderHelper.GetPascalCoinDataFolder+PathDelim+'PascalCointWallet.log';
  end else begin
    FLog.SaveTypes := [];
    FLog.FileName := '';
  end;
  if Assigned(FNode) then begin
    wa := FNode.NetServer.Active;
    FNode.NetServer.Port := TSettings.InternetServerPort;
    FNode.NetServer.Active := wa;
    FNode.Operations.BlockPayload := TEncoding.ANSI.GetBytes(TSettings.MinerName);
    FNode.NodeLogFilename := TFolderHelper.GetPascalCoinDataFolder+PathDelim+'blocks.log';
  end;
  if Assigned(FPoolMiningServer) then begin
    if FPoolMiningServer.Port <> TSettings.MinerServerRpcPort then begin
      FPoolMiningServer.Active := false;
      FPoolMiningServer.Port := TSettings.MinerServerRpcPort;
    end;
    FPoolMiningServer.Active :=TSettings.MinerServerRpcActive;
    FPoolMiningServer.UpdateAccountAndPayload(TWallet.MiningKey, TEncoding.ANSI.GetBytes(TSettings.MinerName));
  end;
  if Assigned(FRPCServer) then begin
    FRPCServer.Active := TSettings.RpcPortEnabled;
    FRPCServer.ValidIPs := TSettings.RpcAllowedIPs;
  end;
end;

class procedure TUserInterface.OnReceivedHelloMessage(Sender: TObject);
Var nsarr : TNodeServerAddressArray;
  i : Integer;
  s : AnsiString;
begin
  // Internal handler
  // No lock required
  //CheckMining;
  // Update node servers Peer Cache
  nsarr := TNetData.NetData.NodeServersAddresses.GetValidNodeServers(true,0);
  s := '';
  for i := low(nsarr) to High(nsarr) do begin
    if (s<>'') then s := s+';';
    s := s + nsarr[i].ip+':'+IntToStr( nsarr[i].port );
  end;
  TSettings.PeerCache := s;

end;

class procedure TUserInterface.OnMiningServerNewBlockFound(Sender: TObject);
begin
  FPoolMiningServer.MinerAccountKey := TWallet.MiningKey;
end;

{%endregion}

{%region Show Dialogs}

class procedure TUserInterface.ShowSendDialog(const AAccounts : array of Cardinal);
var
  Scoped: TDisposables;
  wiz: TWIZSendPASCWizard;
  model: TWIZOperationsModel;
begin
  wiz := Scoped.AddObject(TWIZSendPASCWizard.Create(nil)) as TWIZSendPASCWizard;
  model := TWIZOperationsModel.Create(wiz, omtSendPasc);
  model.Account.SelectedAccounts := TNode.Node.GetAccounts(AAccounts, True);
  model.Account.Count := Length(model.Account.SelectedAccounts);
  wiz.Start(model);
end;

class procedure TUserInterface.ShowChangeKeyDialog(const AAccounts : array of Cardinal);
var
  Scoped: TDisposables;
  wiz: TWIZChangeKeyWizard;
  model: TWIZOperationsModel;
begin
  wiz := Scoped.AddObject(TWIZChangeKeyWizard.Create(nil)) as TWIZChangeKeyWizard;
  model := TWIZOperationsModel.Create(wiz, omtChangeKey);
  model.Account.SelectedAccounts := TNode.Node.GetAccounts(AAccounts, True);
  model.Account.Count := Length(model.Account.SelectedAccounts);
  wiz.Start(model);
end;

class procedure TUserInterface.ShowSellAccountsDialog(const AAccounts : array of Cardinal);
var
  Scoped: TDisposables;
  wiz: TWIZEnlistAccountForSaleWizard;
  model: TWIZOperationsModel;
begin
  wiz := Scoped.AddObject(TWIZEnlistAccountForSaleWizard.Create(nil)) as TWIZEnlistAccountForSaleWizard;
  model := TWIZOperationsModel.Create(wiz, omtEnlistAccountForSale);
  model.Account.SelectedAccounts := TNode.Node.GetAccounts(AAccounts, True);
  model.Account.Count := Length(model.Account.SelectedAccounts);
  wiz.Start(model);
end;

class procedure TUserInterface.ShowDelistAccountsDialog(const AAccounts : array of Cardinal);
var
  Scoped: TDisposables;
  wiz: TWIZDelistAccountFromSaleWizard;
  model: TWIZOperationsModel;
begin
  wiz := Scoped.AddObject(TWIZDelistAccountFromSaleWizard.Create(nil)) as TWIZDelistAccountFromSaleWizard;
  model := TWIZOperationsModel.Create(wiz, omtDelistAccountFromSale);
  model.Account.SelectedAccounts := TNode.Node.GetAccounts(AAccounts, True);
  model.Account.Count := Length(model.Account.SelectedAccounts);
  wiz.Start(model);
end;

class procedure TUserInterface.ShowChangeAccountInfoDialog(
  const AAccounts: array of Cardinal);
var
  Scoped: TDisposables;
  wiz: TWIZChangeAccountInfoWizard;
  model: TWIZOperationsModel;
begin
  wiz := Scoped.AddObject(TWIZChangeAccountInfoWizard.Create(nil)) as TWIZChangeAccountInfoWizard;
  model := TWIZOperationsModel.Create(wiz, omtChangeInfo);
  model.Account.SelectedAccounts := TNode.Node.GetAccounts(AAccounts, True);
  model.Account.Count := Length(model.Account.SelectedAccounts);
  wiz.Start(model);
end;

class procedure TUserInterface.ShowBuyAccountDialog(
  const AAccounts: array of Cardinal);
var
  Scoped: TDisposables;
  wiz: TWIZBuyAccountWizard;
  model: TWIZOperationsModel;
begin
  wiz := Scoped.AddObject(TWIZBuyAccountWizard.Create(nil)) as TWIZBuyAccountWizard;
  model := TWIZOperationsModel.Create(wiz, omtBuyAccount);
  model.Account.SelectedAccounts := TNode.Node.GetAccounts(AAccounts, True);
  model.Account.Count := Length(model.Account.SelectedAccounts);
  wiz.Start(model);
end;

class procedure TUserInterface.ShowAboutBox(parentForm : TForm);
begin
  with TFRMAbout.Create(parentForm) do
  try
    ShowModal;
  finally
    Free;
  end;
end;

class procedure TUserInterface.ShowOptionsDialog(parentForm: TForm);
begin
  With TFRMPascalCoinWalletConfig.Create(parentForm) do
  try
    ShowModal
  finally
    Free;
  end;
end;

class procedure TUserInterface.ShowOperationInfoDialog(parentForm: TForm; const ophash: AnsiString);
begin
  with TFRMPayloadDecoder.Create(parentForm) do
  try
    Init(CT_TOperationResume_NUL);
    if ophash <> '' then
      DoFind(ophash);
    Position := poMainFormCenter;
    ShowModal;
  finally
    Free;
  end;
end;

class procedure TUserInterface.ShowOperationInfoDialog(parentForm: TForm; const operation : TOperationResume); overload;
begin
  with TFRMPayloadDecoder.Create(parentForm) do
  try
    Init(operation);
    Position := poMainFormCenter;
    ShowModal;
  finally
    Free;
  end;
end;

class procedure TUserInterface.ShowAccountInfoDialog(parentForm: TForm; const account: Cardinal);
begin
  if account >= TUserInterface.Node.Bank.AccountsCount then
    raise EUserInterface.Create('Account not found');
  ShowAccountInfoDialog(parentForm, TUserInterface.Node.Operations.SafeBoxTransaction.Account(account));
end;

class procedure TUserInterface.ShowAccountInfoDialog(parentForm: TForm; const account : TAccount); overload;
begin
  ShowMemoText(parentForm, Format('Account: %s', [account.GetAccountString]), account.GetInfoText(Self.Node.Bank));
end;

class procedure TUserInterface.ShowAccountOperationInfoDialog(parentForm: TForm; const account: TAccount; const operation : TOperationResume);
var text : utf8string;
begin
  text := account.GetInfoText(Self.Node.Bank) + sLineBreak + sLineBreak + operation.GetInfoText(Self.Node.Bank);
  ShowMemoText(parentForm, Format('Account/Operation: %s/%s', [account.GetAccountString, operation.GetPrintableOPHASH]), text);
end;

// TODO - refactor with accounts as ARRAY
class procedure TUserInterface.ShowNewOperationDialog(parentForm : TForm; accounts : TOrderedCardinalList; defaultFee : Cardinal);
begin
  If accounts.Count = 0 then raise Exception.Create('No sender accounts provided');
  CheckNodeIsReady;
  With TFRMOperation.Create(parentForm) do
  Try
    SenderAccounts.CopyFrom(accounts);
    DefaultFee := defaultFee;
    WalletKeys := TWallet.Keys;
    ShowModal;
  Finally
    Free;
  End;
end;

class procedure TUserInterface.ShowSeedNodesDialog(parentForm : TForm);
Var FRM : TFRMNodesIp;
begin
  FRM := TFRMNodesIp.Create(parentForm);
  Try
    FRM.ShowModal;
  Finally
    FRM.Free;
  End;
end;

class procedure TUserInterface.ShowPrivateKeysDialog(parentForm: TForm);
Var FRM : TFRMWalletKeys;
begin
  FRM := TFRMWalletKeys.Create(parentForm);
  try
    FRM.ShowModal;
  finally
    FRM.Free;
  end;
end;

class procedure TUserInterface.ShowMemoText(parentForm: TForm; const ATitle : AnsiString; text : utf8string);
begin
  with TFRMMemoText.Create(parentForm) do begin
    try
      Caption := ATitle;
      Memo.Append(text);
      Position := poMainFormCenter;
      ShowModal;
    finally
      Free;
    end;
  end;
end;

class procedure TUserInterface.ShowMemoText(parentForm: TForm; const ATitle : AnsiString; text : TStrings);
begin
  with TFRMMemoText.Create(parentForm) do begin
    try
      Caption := ATitle;
      Memo.Lines.Assign(text);
      Position := poMainFormCenter;
      ShowModal;
    finally
      Free;
    end;
  end;
end;

class procedure TUserInterface.ChangeWalletPassword(parentForm: TForm);
var
  pwd1,pwd2 : String;
  locked : boolean;
begin
  pwd1 := ''; pwd2 := '';
  locked := (NOT TWallet.Keys.HasPassword) OR (NOT TWallet.Keys.IsValidPassword);
  if Not AskEnterProtectedString(parentForm, 'Change password','Enter new password',pwd1)
    then exit;
  if trim(pwd1)<>pwd1 then
    raise Exception.Create('Password cannot start or end with a space character');
  if Not AskEnterProtectedString(parentForm, 'Change password', 'Enter new password again',pwd2)
    then exit;
  if pwd1<>pwd2 then
    raise Exception.Create('Two passwords are different!');
  TWallet.Keys.WalletPassword := pwd1;
  if locked then
    TWallet.Keys.LockWallet;

  ShowWarning(parentform,
  'Password Changed',
  'Your password has been changed.' + #10+#10 +
  'Please ensure you remember your password.'+#10+
  'If you lose your password your accounts and funds will be lost forever.');
end;

{$IFDEF TESTNET}
class procedure TUserInterface.ShowRandomOperationsDialog(parentForm: TForm);
begin
  with TFRMRandomOperations.Create(parentForm) do begin
    try
      SourceNode := TUserInterface.Node;
      SourceWalletKeys := TWallet.Keys;
      ShowModal;
    finally
      Free;
    end;
  end;
end;

class procedure TUserInterface.ShowPublicKeysDialog(parentForm: TForm);
var
  sl : TStrings;
  ak : TAccountKey;
  i, nmin,nmax : Integer;
  l : TList;
  Pacsd : PAccountKeyStorageData;
  acc : TAccount;
begin
   sl := TStringList.Create;
  try
    for i:=0 to FNode.Bank.SafeBox.AccountsCount-1 do begin
      acc := FNode.Bank.SafeBox.Account(i);
      if acc.accountInfo.new_publicKey.EC_OpenSSL_NID<>0 then begin
        sl.Add(Format('Account %d new public key %d %s',[acc.account,
          acc.accountInfo.new_publicKey.EC_OpenSSL_NID,
          TCrypto.ToHexaString(TAccountComp.AccountKey2RawString(acc.accountInfo.new_publicKey))]));
      end;
    end;
    l := TAccountKeyStorage.KS.LockList;
    try
      sl.Add(Format('%d public keys in TAccountKeyStorage data',[l.count]));
      for i:=0 to l.count-1 do begin
        Pacsd := l[i];
        if (Pacsd^.counter<=0) then begin
          sl.Add(Format('%d/%d public keys counter %d',[i+1,l.count,Pacsd^.counter]));
        end;
        if FNode.Bank.SafeBox.OrderedAccountKeysList.IndexOfAccountKey(Pacsd^.ptrAccountKey^)<0 then begin
          sl.Add(Format('%d/%d public keys counter %d Type %d NOT FOUND %s',[i+1,l.count,Pacsd^.counter,
          Pacsd^.ptrAccountKey^.EC_OpenSSL_NID,
          TCrypto.ToHexaString(TAccountComp.AccountKey2RawString(Pacsd^.ptrAccountKey^))]));
        end;
      end;
    finally
      TAccountKeyStorage.KS.UnlockList;
    end;
    sl.Add(Format('%d public keys in %d accounts',[FNode.Bank.SafeBox.OrderedAccountKeysList.Count,FNode.Bank.Safebox.AccountsCount]));
    for i:=0 to FNode.Bank.SafeBox.OrderedAccountKeysList.Count-1 do begin
      ak := FNode.Bank.SafeBox.OrderedAccountKeysList.AccountKey[i];
      if ( FNode.Bank.SafeBox.OrderedAccountKeysList.AccountKeyList[i].Count > 0) then begin
        nmin := FNode.Bank.SafeBox.OrderedAccountKeysList.AccountKeyList[i].Get(0);
        nmax := FNode.Bank.SafeBox.OrderedAccountKeysList.AccountKeyList[i].Get( FNode.Bank.SafeBox.OrderedAccountKeysList.AccountKeyList[i].Count-1 );
      end else begin
        nmin := -1; nmax := -1;
      end;
      sl.Add(Format('%d/%d %d accounts (%d to %d) for key type %d %s',[
        i+1,FNode.Bank.SafeBox.OrderedAccountKeysList.Count,
        FNode.Bank.SafeBox.OrderedAccountKeysList.AccountKeyList[i].Count,
        nmin,nmax,
        ak.EC_OpenSSL_NID,
        TCrypto.ToHexaString(TAccountComp.AccountKey2RawString(ak)) ]));
    end;
    with TFRMMemoText.Create(parentForm) do begin
    try
      InitData('Keys in safebox',sl.Text);
      ShowModal;
    finally
      Free;
    end;

    end;
  finally
    sl.Free;
  end;
end;

{$IFDEF TESTING_NO_POW_CHECK}
class procedure TUserInterface.CreateABlock;
var
  ops : TPCOperationsComp;
  nba : TBlockAccount;
  errors : AnsiString;
begin
  ops := TPCOperationsComp.Create(Nil);
  Try
    ops.bank := FNode.Bank;
    ops.CopyFrom(FNode.Operations);
    ops.BlockPayload:= IntToStr(FNode.Bank.BlocksCount);
    ops.nonce := FNode.Bank.BlocksCount;
    ops.UpdateTimestamp;
    FNode.AddNewBlockChain(Nil,ops,nba,errors);
  finally
    ops.Free;
  end;
end;
{$ENDIF}
{$ENDIF}

class procedure TUserInterface.UnlockWallet(parentForm: TForm);
Var pwd : String;
begin
  pwd := '';
  Repeat
    if Not AskEnterProtectedString(parentForm, 'Wallet password','Enter wallet password',pwd) then exit;
    TWallet.Keys.WalletPassword := pwd;
    if Not TWallet.Keys.IsValidPassword then
      ShowError(parentForm, 'Invalid Password', 'The password you have entered is incorrect.');
  Until TWallet.Keys.IsValidPassword;
end;

class procedure TUserInterface.ShowInfo(parentForm : TForm; const ACaption, APrompt : String);
begin
  MessageDlg(ACaption, APrompt, mtInformation, [mbOK], 0, mbOK);
end;

class procedure TUserInterface.ShowWarning(parentForm : TForm; const ACaption, APrompt : String);
begin
  MessageDlg(ACaption, APrompt, mtWarning, [mbOK], 0, mbOK);
end;

class procedure TUserInterface.ShowError(parentForm : TForm; const ACaption, APrompt : String);
begin
  MessageDlg(ACaption, APrompt, mtError, [mbOK], 0, mbOK);
end;

class function TUserInterface.AskQuestion(parentForm: TForm; AType:TMsgDlgType; const ACaption, APrompt : String; buttons: TMsgDlgButtons) : TMsgDlgBtn;
var modalResult : TModalResult;
begin
  modalResult := MessageDlg(ACaption, APrompt, AType, Buttons, 0, mbNo);
  case modalResult of
    mrYes: Result := mbYes;
    mrNo: Result := mbNo;
    mrOK: Result := mbOK;
    mrCancel: Result := mbCancel;
    mrAbort: Result := mbAbort;
    mrRetry: Result := mbRetry;
    mrIgnore:Result := mbIgnore;
    mrAll: Result := mbAll;
    mrNoToAll: Result := mbNoToAll;
    mrYesToAll: Result := mbYesToAll;
    mrClose: Result := mbClose;
    else raise Exception.Create('Internal Error: [TUserInterface.AskQuestion] unsupported dialog result');
  end;
end;

class function TUserInterface.AskEnterString(parentForm: TForm; const ACaption, APrompt : String; var Value : String) : Boolean;
begin
  Result := InputQuery(ACaption, APrompt, Value);
end;

class function TUserInterface.AskEnterProtectedString(parentForm: TForm; const ACaption, APrompt : String; var Value : String) : Boolean;
begin
  Result := InputQuery(ACaption, APrompt, true, Value);
end;

{%endregion}

{%region Show Forms}

class procedure TUserInterface.ShowAccountExplorer;
begin
  FUILock.Acquire;
  try
    if not Assigned(FAccountExplorer) then begin
       FAccountExplorer := TFRMAccountExplorer.Create(FMainForm);
       FAccountExplorer.CloseAction:= caFree;
       FAccountExplorer.OnDestroyed:= Self.OnSubFormDestroyed;
    end else
      FAccountExplorer.Refresh;
    FAccountExplorer.Show;
  finally
    FUILock.Release;
  end;
end;

class procedure TUserInterface.ShowBlockExplorer;
begin
  FUILock.Acquire;
  try
    if not Assigned(FBlockExplorerForm) then begin
       FBlockExplorerForm := TFRMBlockExplorer.Create(FMainForm);
       FBlockExplorerForm.CloseAction:= caFree;
       FBlockExplorerForm.OnDestroyed:= Self.OnSubFormDestroyed;
    end;
    FBlockExplorerForm.Show;
  finally
    FUILock.Release;
  end;
end;

class procedure TUserInterface.ShowOperationsExplorer;
begin
  FUILock.Acquire;
  try
    if not Assigned(FOperationsExplorerForm) then begin
      FOperationsExplorerForm := TFRMOperationExplorer.Create(FMainForm);
      FOperationsExplorerForm.CloseAction:= caFree;
      FOperationsExplorerForm.OnDestroyed:= Self.OnSubFormDestroyed;
    end;
    FOperationsExplorerForm.Show;
  finally
    FUILock.Release;
  end;
end;

class procedure TUserInterface.ShowPendingOperations;
begin
  FUILock.Acquire;
  try
    if not Assigned(FPendingOperationForm) then begin
      FPendingOperationForm := TFRMPendingOperations.Create(FMainForm);
      FPendingOperationForm.CloseAction:= caFree;
      FPendingOperationForm.OnDestroyed:= Self.OnSubFormDestroyed;
    end;
    FPendingOperationForm.Show;
  finally
    FUILock.Release;
  end;
end;

class procedure TUserInterface.ShowMessagesForm;
begin
  FUILock.Acquire;
  try
    if not Assigned(FMessagesForm) then begin
       FMessagesForm := TFRMMessages.Create(FMainForm);
       FMessagesForm.CloseAction:= caFree;
       FMessagesForm.OnDestroyed:= Self.OnSubFormDestroyed;
    end;
    FMessagesForm.Show;
  finally
    FUILock.Release;
  end;
end;

class procedure TUserInterface.ShowNodesForm;
begin
  FUILock.Acquire;
  try
    if not Assigned(FNodesForm) then begin
       FNodesForm := TFRMNodes.Create(FMainForm);
       FNodesForm.CloseAction:= caFree;
       FNodesForm.OnDestroyed:= Self.OnSubFormDestroyed;
    end;
    FNodesForm.Show;
  finally
    FUILock.Release;
  end;
end;

class procedure TUserInterface.ShowLogsForm;
begin
  FUILock.Acquire;
  try
    if not Assigned(FLogsForm) then begin
       FLogsForm := TFRMLogs.Create(FMainForm);
       FLogsForm.CloseAction:= caFree;
       FLogsForm.OnDestroyed:= Self.OnSubFormDestroyed;
    end;
    FLogsForm.Show;
  finally
    FUILock.Release;
  end;
end;

class procedure TUserInterface.ShowWallet;
begin
  FMainForm.Mode := wmWallet;
end;

class procedure TUserInterface.ShowSyncDialog;
begin
  FMainForm.Mode := wmSync;
end;

{%endregion}

{%region Public methods}

class procedure TUserInterface.CheckNodeIsReady;
Var errorMessage : AnsiString;
begin
  if Not TNode.Node.IsReady(errorMessage) then begin
    Raise Exception.Create('You cannot do this operation now:'+#10+#10+errorMessage);
  end;
end;

{%endregion}

{%region Auxillary methods}

class function TUserInterface.GetEnabled : boolean;
begin
  Result := FMainForm.Enabled;
end;

class procedure TUserInterface.SetEnabled(ABool: boolean);
begin
  if Assigned(FMainForm) then
    FMainForm.Enabled:=ABool;
end;

class procedure TUserInterface.SetState(AState : TUserInterfaceState); static;
begin
  if AState = FState then
    exit;
  FState := AState;
  NotifyStateChanged(nil);
end;

class procedure TUserInterface.NotifyLoadedEvent(Sender: TObject);
begin
  TUserInterface.FLoaded.Invoke(Sender);
end;

class procedure TUserInterface.NotifyLoadingEvent(Sender: TObject; const message: AnsiString; curPos, totalCount: Int64);
begin
  TUserInterface.FLoading.Invoke(Sender, message, curPos, totalCount);
end;

class procedure TUserInterface.NotifyStateChanged(Sender: TObject);
begin
  TUserInterface.FStateChanged.Invoke(Sender);
end;

class procedure TUserInterface.NotifyAccountsChangedEvent(Sender: TObject);
begin
  TUserInterface.FAccountsChanged.Invoke(Sender);
end;

class procedure TUserInterface.NotifyBlocksChangedEvent(Sender: TObject);
begin
  TUserInterface.FBlocksChanged.Invoke(Sender);
end;

class procedure TUserInterface.NotifyNodeMessageEventEvent(NetConnection: TNetConnection; MessageData: String);
begin
  TUserInterface.FNodeMessageEvent.Invoke(NetConnection, MessageData);
end;

class procedure TUserInterface.NotifyReceivedHelloMessageEvent(Sender: TObject);
begin
  TUserInterface.FReceivedHelloMessage.Invoke(Sender);;
end;

class procedure TUserInterface.NotifyNetStatisticsChangedEvent(Sender: TObject);
begin
  TUserInterface.FNetStatisticsChanged.Invoke(Sender);
end;

class procedure TUserInterface.NotifyNetConnectionsUpdatedEvent(Sender: TObject);
begin
  TUserInterface.FNetConnectionsUpdated.Invoke(Sender);
end;

class procedure TUserInterface.NotifyNetNodeServersUpdatedEvent(Sender: TObject);
begin
  TUserInterface.NetNodeServersUpdated.Invoke(Sender);
end;

class procedure TUserInterface.NotifyNetBlackListUpdatedEvent(Sender: TObject);
begin
  TUserInterface.FNetBlackListUpdated.Invoke(Sender);
end;

class procedure TUserInterface.NotifyMiningServerNewBlockFoundEvent(Sender: TObject);
begin
  TUserInterface.FMiningServerNewBlockFound.Invoke(Sender);
end;

class procedure TUserInterface.NotifyUIRefreshTimerEvent(Sender: TObject);
begin
  TUserInterface.FUIRefreshTimer.Invoke(Sender);
end;

{%endregion}

{ TLoadDatabaseThread }

procedure TLoadDatabaseThread.OnProgressNotify(sender: TObject; const message: AnsiString; curPos, totalCount: Int64);
begin
  TUserInterface.NotifyLoadingEvent(sender, message, curPos, totalCount);
end;

procedure TLoadDatabaseThread.OnLoaded;
begin
  TUserInterface.NotifyLoadedEvent(Self);
end;

procedure TLoadDatabaseThread.BCExecute;
begin
  // Read Operations saved from disk
  TNode.Node.InitSafeboxAndOperations($FFFFFFFF, OnProgressNotify);
  TNode.Node.AutoDiscoverNodes(CT_Discover_IPs);
  TNode.Node.NetServer.Active := true;
  Synchronize( OnLoaded );
end;

initialization
// TODO - any startup code needed here?
finalization
// TODO - final cleanup here, show a modal dialog?
end.
