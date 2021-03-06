---------------------------- MODULE Chain ----------------------------

EXTENDS Naturals, FiniteSets, RelayerDefinitions, 
        ClientHandlers, ConnectionHandlers, ChannelHandlers
        
CONSTANTS ChainID, \* chain identifier
          Heights \* set of possible heights of the chains in the system 

VARIABLES chainStore,
          incomingDatagrams

vars == <<chainStore, incomingDatagrams>>          

(***************************************************************************
 Client update operators
 ***************************************************************************)
\* Update the clients on chain with chainID, 
\* using the client datagrams generated by the relayer      
\* (Handler operators defined in ClientHandlers.tla)
LightClientUpdate(chainID, store, datagrams) == 
    \* create clients
    LET clientCreatedStore == HandleCreateClient(chainID, store, datagrams) IN
    \* update clients
    LET clientUpdatedStore == HandleUpdateClient(chainID, clientCreatedStore, datagrams) IN

    clientUpdatedStore
    
(***************************************************************************
 Connection update operators
 ***************************************************************************)
\* Update the connections on chain with chainID, 
\* using the connection datagrams generated by the relayer
\* (Handler operators defined in ConnectionHandlers.tla)
ConnectionUpdate(chainID, store, datagrams) ==
    \* update the chain store with "ConnOpenInit" datagrams
    LET connOpenInitStore == HandleConnOpenInit(chainID, store, datagrams) IN
    \* update the chain store with "ConnOpenTry" datagrams
    LET connOpenTryStore  == HandleConnOpenTry(chainID, connOpenInitStore, datagrams) IN
    \* update the chain store with "ConnOpenAck" datagrams
    LET connOpenAckStore == HandleConnOpenAck(chainID, connOpenTryStore, datagrams) IN
    \* update the chain store with "ConnOpenConfirm" datagrams
    LET connOpenConfirmStore == HandleConnOpenConfirm(chainID, connOpenAckStore, datagrams) IN
    
    connOpenConfirmStore

(***************************************************************************
 Channel update operators
 ***************************************************************************)
\* Update the channels on chain with chainID, 
\* using the channel datagrams generated by the relayer
\* (Handler operators defined in ChannelHandlers.tla)
ChannelUpdate(chainID, store, datagrams) ==
    \* update the chain store with "ChanOpenInit" datagrams
    LET chanOpenInitStore == HandleChanOpenInit(chainID, store, datagrams) IN
    \* update the chain store with "ChanOpenTry" datagrams
    LET chanOpenTryStore == HandleChanOpenTry(chainID, chanOpenInitStore, datagrams) IN
    \* update the chain store with "ChanOpenAck" datagrams
    LET chanOpenAckStore == HandleChanOpenAck(chainID, chanOpenTryStore, datagrams) IN
    \* update the chain store with "ChanOpenConfirm" datagrams
    LET chanOpenConfirmStore == HandleChanOpenConfirm(chainID, chanOpenAckStore, datagrams) IN
    
    \* update the chain store with "ChanCloseInit" datagrams
    LET chanCloseInitStore == HandleChanCloseInit(chainID, chanOpenConfirmStore, datagrams) IN
    \* update the chain store with "ChanCloseConfirm" datagrams
    LET chanCloseConfirmStore == HandleChanCloseConfirm(chainID, chanCloseInitStore, datagrams) IN
    
    chanCloseConfirmStore

(***************************************************************************
 Chain update operators
 ***************************************************************************)
\* Update chainID with the received datagrams
\* Supports ICS2 (Clients), ICS3 (Connections), and ICS4 (Channels).
UpdateChainStore(chainID, datagrams) == 
    \* ICS 002: Client updates
    LET lightClientsUpdatedStore == LightClientUpdate(chainID, chainStore, datagrams) IN 
    \* ICS 003: Connection updates
    LET connectionsUpdatedStore == ConnectionUpdate(chainID, lightClientsUpdatedStore, datagrams) IN
    \* ICS 004: Channel updates
    LET channelsUpdatedStore == ChannelUpdate(chainID, connectionsUpdatedStore, datagrams) IN
    
    \* update height
    LET updatedChainStore == 
        IF /\ chainStore /= channelsUpdatedStore
           /\ chainStore.height + 1 \in Heights 
        THEN [channelsUpdatedStore EXCEPT !.height = chainStore.height + 1]
        ELSE channelsUpdatedStore
    IN
    
    updatedChainStore

(***************************************************************************
 Chain actions
 ***************************************************************************)       
\* Advance the height of the chain until MaxHeight is reached
AdvanceChain ==
    /\ chainStore.height + 1 \in Heights
    /\ chainStore' = [chainStore EXCEPT !.height = chainStore.height + 1]
    /\ UNCHANGED incomingDatagrams

\* Handle the datagrams and update the chain state        
HandleIncomingDatagrams ==
    /\ incomingDatagrams /= {} 
    /\ chainStore' = UpdateChainStore(ChainID, incomingDatagrams)
    /\ incomingDatagrams' = {}

(***************************************************************************
 Specification
 ***************************************************************************)
\* Initial state predicate
\* Initially
\*  - each chain is initialized to InitChain (defined in RelayerDefinitions.tla)
\*  - pendingDatagrams for each chain is empty
Init == 
    /\ chainStore = InitChain 
    /\ incomingDatagrams = {}

\* Next state action
\* The chain either
\*  - advances its height
\*  - receives datagrams and updates its state
Next ==
    \/ AdvanceChain
    \/ HandleIncomingDatagrams
    \/ UNCHANGED vars
    
Fairness ==
    /\ WF_vars(AdvanceChain)
    /\ WF_vars(HandleIncomingDatagrams)
        
(***************************************************************************
 Invariants
 ***************************************************************************)
\* Type invariant   
\* Chains and Datagrams are defined in RelayerDefinitions.tla        
TypeOK ==    
    /\ chainStore \in Chains
    /\ incomingDatagrams \in SUBSET Datagrams(Heights)
    
(***************************************************************************
 Properties
 ***************************************************************************)    
\* it ALWAYS holds that the height of the chain does not EVENTUALLY decrease
HeightDoesntDecrease ==
    [](\A h \in Heights : chainStore.height = h 
        => <>(chainStore.height >= h))

=============================================================================
\* Modification History
\* Last modified Fri Jul 10 16:13:04 CEST 2020 by ilinastoilkovska
\* Created Fri Jun 05 16:56:21 CET 2020 by ilinastoilkovska
