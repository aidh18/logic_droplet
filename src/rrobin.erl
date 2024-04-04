%%%-------------------------------------------------------------------
%%% @author Lee Barney  <barney.cit@gmail.com>
%%% @copyright © 2023, Lee S. Barney
%%% @reference Licensed under the
%%% <a href="http://creativecommons.org/licenses/by/4.0/">
%%% Creative Commons Attribution 4.0 International License</a>.
%%%
%%% @doc
%%% This is a round robin selector. Given a set of valid Erlang types,
%%%  this selector distributes work in a
%%% <a href="https://www.techtarget.com/whatis/definition/round-robin">
%%% round-robin</a> fashion.
%%%
%%% @end
%%
-module(rrobin).
-behaviour(gen_server).

%% API
-export([start/1,start/3,stop/0,stop/1,next/0,next/1]).

%% gen_server callbacks
-export([init/1, handle_call/3, handle_cast/2, handle_info/2,
         terminate/2, code_change/3]).

%%%===================================================================
%%% API
%%%===================================================================

%%--------------------------------------------------------------------
%% @doc
%% Starts the server assuming there is only one server started for
%% this module. The server is registered locally with the registered
%% name being the name of the module.
%%
%% Parameters: Identifiers - a list of any valid erlang terms. Often,
%% these are PIDs or other identifiers.
%%
%% Value: a 2-tuple consisting of _ok_ followed by the process ID of
%% the spawned rr_selector gen_server.
%%
%%
%% @end
%%--------------------------------------------------------------------
-spec start(list()) -> {ok, pid()} | ignore | {error, term()}.
start(Identifiers) ->
    gen_server:start_link({local, ?MODULE}, ?MODULE, {Identifiers,[]}, []).
%%--------------------------------------------------------------------
%% @doc
%% Starts a server using this module and registers the server using
%% the name given.
%% Registration_type can be local or global.
%%
%%
%% Parameters: Registration_type - local or global atoms.
%%             Name - the name under which this rr_selector is registered
%%             Identifiers - a list of any valid erlang terms. Often,
%% these are PIDs or other identifiers.
%%
%% Value: a 2-tuple consisting of _ok_ followed by the process ID of
%% the spawned rr_selector gen_server.
%%
%% @end
%%--------------------------------------------------------------------
-spec start(atom(),atom(),atom()) -> {ok, pid()} | ignore | {error, term()}.
start(Registration_type,Name,Identifiers) ->
    gen_server:start_link({Registration_type, Name}, ?MODULE, {Identifiers,[]}, []).


%%--------------------------------------------------------------------
%% @doc
%% Stops the server gracefully
%%
%% @end
%%--------------------------------------------------------------------
-spec stop() -> {ok}|{error, term()}.
stop() -> gen_server:call(?MODULE, stop).

%%--------------------------------------------------------------------
%% @doc
%% Stops the server gracefully when it has a registered name
%%
%% @end
%%--------------------------------------------------------------------
-spec stop(atom()) -> {ok}|{error, term()}.
stop(Registered_name) -> gen_server:call(Registered_name, stop).

%% Any other API functions go here.

%%--------------------------------------------------------------------
%% @doc
%% Retrieves the next identifier to be used from a rr_selector spawned
%% using the module name as the registered name for the rr_selector
%% gen_server.
%%
%%
%% Parameters: None.
%%
%% Value: a valid Erlang type.
%%
%% @end
%%--------------------------------------------------------------------

-spec next() -> term().
next()-> gen_server:call(?MODULE, next).

%%--------------------------------------------------------------------
%% @doc
%% Retrieves the next identifier to be used from a rr_selector spawned
%% using a specified name as the registered name for the rr_selector
%% gen_server.
%%
%%
%% Parameters: Name - an atom that is the registered name of the
%% rr_selector gen_server to be used.
%%
%% Value: a valid Erlang type.
%%
%% @end
%%--------------------------------------------------------------------

-spec next(atom()) -> term().
next(Name)-> gen_server:call(Name, next).

%%%===================================================================
%%% gen_server callbacks
%%%===================================================================

%%--------------------------------------------------------------------
%% @private
%% @doc
%% Initializes the server
%%
%% @end
%%--------------------------------------------------------------------
-spec init(list()) -> {ok, term()}|{ok, term(), number()}|ignore |{stop, term()}.
init(Identifiers) ->
    {ok,Identifiers}.
%%--------------------------------------------------------------------
%% @private
%% @doc
%% Handling call messages
%%
%% @end
%%--------------------------------------------------------------------
-spec handle_call(Message::term(), From::pid(), State::term()) ->
                                  {reply, term(), term()} |
                                  {reply, term(), term(), integer()} |
                                  {noreply, term()} |
                                  {noreply, term(), integer()} |
                                  {stop, term(), term(), integer()} |
                                  {stop, term(), term()}.

handle_call(next, _From, {[],[]}=State) ->
        {reply,empty_list_error,State};
handle_call(next, _From, {Front,Back}) when is_list(Front) == false ->
        {reply,non_list_error,{[],[]}};
handle_call(next, _From, {[H|T],[]}) ->
        {reply,H,{T,[H]}};
handle_call(next, _From, {[],Back}) ->
        [H|T] = lists:reverse(Back),
        {reply,H,{T,[H]}};
handle_call(next, _From, {[H|T],Back}) ->
        {reply,H,{T,[H]++Back}};
handle_call(stop, _From, _State) ->
        {stop,normal,
                ok,
          down}. %% setting the server's internal state to down

%%--------------------------------------------------------------------
%% @private
%% @doc
%% Handling cast messages
%%
%% @end
%%--------------------------------------------------------------------
-spec handle_cast(Msg::term(), State::term()) -> {noreply, term()} |
                                  {noreply, term(), integer()} |
                                  {stop, term(), term()}.
handle_cast(_Msg, State) ->
    {noreply, State}.

%%--------------------------------------------------------------------
%% @private
%% @doc
%% Handling all non call/cast messages
%%
%% @end
-spec handle_info(Info::term(), State::term()) -> {noreply, term()} |
                                   {noreply, term(), integer()} |
                                   {stop, term(), term()}.
handle_info(_Info, State) ->
    {noreply, State}.

%%--------------------------------------------------------------------
%% @private
%% @doc
%% This function is called by a gen_server when it is about to
%% terminate. It should be the opposite of Module:init/1 and do any
%% necessary cleaning up. When it returns, the gen_server terminates
%% with Reason. The return value is ignored.
%%
%% @end
%%--------------------------------------------------------------------
-spec terminate(Reason::term(), term()) -> term().
terminate(_Reason, _State) ->
    ok.

%%--------------------------------------------------------------------
%% @private
%% @doc
%% Convert process state when code is changed
%%
%% @end
%%--------------------------------------------------------------------
-spec code_change(term(), term(), term()) -> {ok, term()}.
code_change(_OldVsn, State, _Extra) ->
    {ok, State}.

%%%===================================================================
%%% Internal functions
%%%===================================================================


%% This code is included in the compiled code only if
%% 'rebar3 eunit' is being executed.
%% Only include the eunit testing libary
%% in the compiled code if testing is
%% being done.
-ifdef(TEST).
-include_lib("eunit/include/eunit.hrl").

%%
%% Test to see if the worker list is dealt with correctly by
%% handle_event.
%%
handle_event_test_() ->
    %happy paths
    [?_assertMatch({reply,sue,{[bob,sally,grace],[sue]}},
        rrobin:handle_call(next,some_from,{[sue,bob,sally,grace],[]})),
     ?_assertMatch({reply,bob,{[sally,grace],[bob,sue]}},
        rrobin:handle_call(next, some_from, {[bob,sally,grace],[sue]})),
     %nasty thoughts start here
     %test if list is empty
     ?_assertMatch({reply,empty_list_error,{[],[]}},
        rrobin:handle_call(next, some_from, {[],[]})),
     %test if state is not a tuple of lists
     ?_assertMatch({reply,non_list_error,{[],[]}},
        rrobin:handle_call(next, some_from, {true,[]}))

    ].

component_no_name_test_()->
  {setup,
    fun()-> ?MODULE:start([pid1,pid2,pid3,pid4,pid5]) end,
    fun(_)-> ?MODULE:stop() end,%wait_for_exit(?MODULE) end,
    [?_assertEqual(pid1,rrobin:next()),
     ?_assertEqual(pid2,rrobin:next()),
     ?_assertEqual(pid3,rrobin:next()),
     ?_assertEqual(pid4,rrobin:next()),
     ?_assertEqual(pid5,rrobin:next()),
     ?_assertEqual(pid1,rrobin:next())
    ]
  }.
component_registered_name_test_()->
  {setup,
    fun()-> ?MODULE:start(local,tester,[pid1,pid2,pid3,pid4,pid5]) end,
    fun(_)-> ?MODULE:stop(tester) end,%wait_for_exit(?MODULE) end,
    [?_assertEqual(pid1,rrobin:next(tester)),
     ?_assertEqual(pid2,rrobin:next(tester)),
     ?_assertEqual(pid3,rrobin:next(tester)),
     ?_assertEqual(pid4,rrobin:next(tester)),
     ?_assertEqual(pid5,rrobin:next(tester)),
     ?_assertEqual(pid1,rrobin:next(tester))
    ]
  }.

not_list_test_()->
  {setup,
    fun()-> ?MODULE:start(not_a_list) end,
    fun(_)-> ?MODULE:stop() end,%wait_for_exit(?MODULE) end,
    [?_assertEqual(non_list_error,rrobin:next()),
     ?_assertEqual(empty_list_error,rrobin:next()),
     ?_assertEqual(empty_list_error,rrobin:next())
    ]
  }.

-endif.
