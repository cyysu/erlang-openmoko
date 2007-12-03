-module(addressbook_gui).
-behaviour(gen_server).

-export([start_link/0]).
-export([init/1, handle_call/3, handle_cast/2, handle_info/2, terminate/2, code_change/3]).

-include("openmoko.hrl").
-include("openmoko_addressbook.hrl").

-define(W, addressbook_gui_node).

start_link() ->
    gen_server:start_link({local, ?MODULE}, ?MODULE, [], []).

%---------------------------------------------------------------------------
%% Implementation

-record(state, {list_store, current_record}).

init_gui() ->
    gui:start_glade(?W, "addressbook.glade"),
    ListStore = gui:new_list_store(?W, [string, string]),
    C0 = gui:new_tree_view_column(?W, 0, "Name"),
    C1 = gui:new_tree_view_column(?W, 1, "Number"),
    gui:cmd(?W, 'Gtk_tree_view_set_model', [index_view, ListStore]),
    gui:cmd(?W, 'Gtk_tree_view_append_column', [index_view, C0]),
    gui:cmd(?W, 'Gtk_tree_view_append_column', [index_view, C1]),

    lists:foreach(fun (#addressbook_entry{name = Name, phone_number = PhoneNumber}) ->
			  gui:list_store_append(?W, ListStore),
			  gui:list_store_set(?W, ListStore, 0, Name),
			  gui:list_store_set(?W, ListStore, 1, PhoneNumber)
		  end, openmoko_addressbook:list()),

    {ok, ListStore}.

stop_gui() ->
    gui:stop(?W),
    ok.

%---------------------------------------------------------------------------
%% gen_server behaviour

init([]) ->
    {ok, ListStore} = init_gui(),
    {ok, #state{list_store = ListStore,
		current_record = none}}.

handle_call(_Request, _From, State) ->
    {reply, not_understood, State}.

handle_cast(Message, State) ->
    error_logger:info_msg("Unknown sms_manager:handle_cast ~p~n", [Message]),
    {noreply, State}.

handle_info({?W, {signal, {call_button, clicked}}},
	    State = #state{current_record = CurrentRecord}) ->
    case CurrentRecord of
	none -> ignored;
	#addressbook_entry{phone_number = Number}  ->
	    call_manager:place_call(Number)
    end,
    {noreply, State};
handle_info({?W, {signal, {index_view, 'cursor-changed'}}},
	    State = #state{list_store = ListStore}) ->
    SelectedRowPaths = gui:cmd(?W, 'GN_tree_view_get_selected', [index_view]),
    case SelectedRowPaths of
	[] ->
	    {noreply, State#state{current_record = none}};
	[Path | _] ->
	    gui:cmd(?W, 'Gtk_tree_model_get_iter_from_string', [ListStore, selection_iter, Path]),
	    gui:cmd(?W, 'Gtk_tree_model_get_value', [ListStore, selection_iter, 0, selval]),
	    Name = gui:cmd(?W, 'GN_value_get', [selval]),
	    gui:cmd(?W, 'GN_value_unset', [selval]),
	    {ok, Record} = openmoko_addressbook:lookup(Name),
	    {noreply, State#state{current_record = Record}}
    end;
handle_info(Message, State) ->
    error_logger:info_msg("Unknown sms_manager:handle_info ~p~n", [Message]),
    {noreply, State}.

terminate(_Reason, _State) ->
    stop_gui(),
    ok.

code_change(_OldVsn, State, _Extra) ->
    stop_gui(),
    init_gui(),
    {ok, State}.