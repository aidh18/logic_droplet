%% @author Lee Barney
%% @copyright 2022 Lee Barney licensed under the <a>
%%        rel="license"
%%        href="http://creativecommons.org/licenses/by/4.0/"
%%        target="_blank">
%%        Creative Commons Attribution 4.0 International License</a>
%%
%%
-module(logic).
-behavior(gen_server).


%% API
-export([start/0,start/3,stop/0]).

%% gen_server callbacks
-export([init/1,deliver_api/1,request_location_api/1,transfer_package_api/1,
         update_location_api/1,handle_call/3,handle_cast/3,handle_cast/2,
         handle_info/2,terminate/2,code_change/3]).


%%%===================================================================
%%% API
%%%===================================================================

%%--------------------------------------------------------------------
%% @doc
%% Starts the server assuming there is only one server started for 
%% this module. The server is registered locally with the registered
%% name being the name of the module.
%%
%% @end
%%--------------------------------------------------------------------
-spec start() -> {ok,pid()} | ignore | {error,term()}.
start() ->
    gen_server:start_link({local,?MODULE},?MODULE,[],[]).
%%--------------------------------------------------------------------
%% @doc
%% Starts a server using this module and registers the server using
%% the name given.
%% Registration_type can be local or global.
%%
%% Args is a list containing any data to be passed to the gen_server's
%% init function.
%%
%% @end
%%--------------------------------------------------------------------
-spec start(atom(),atom(),atom()) -> {ok,pid()} | ignore | {error,term()}.
start(Registration_type,Name,Args) ->
    gen_server:start_link({Registration_type,Name},?MODULE,Args,[]).


%%--------------------------------------------------------------------
%% @doc
%% Stops the server gracefully
%%
%% @end
%%--------------------------------------------------------------------
-spec stop() -> {ok}|{error,term()}.
stop() -> gen_server:call(?MODULE,stop).

%% Any other API functions go here.
deliver_api(Package_id) ->
    gen_server:cast({deliver,<<Package_id>>},self(),db_pid).

request_location_api(Package_id) ->
    gen_server:call({request_location,<<Package_id>>},self(),db_pid),
    receive
        {reply,{fail,empty_key},_} -> 500;
        {reply,{fail,invalid_key},_} -> 500;
        {reply,{Lat,Long},_} -> {Lat,Long}
    end.



transfer_package_api({Package_id, Location_id}) ->
    gen_server:cast({transfer_package,<<Package_id>>,<<Location_id>>},self(),db_pid).

update_location_api({Location_id,{Lat,Long}}) ->
    gen_server:cast({update_location,<<Location_id>>,{Lat,Long}},self(),db_pid).

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
-spec init(term()) -> {ok,term()}|{ok,term(),number()}|ignore |{stop,term()}.
init([]) ->
    {ok, Pid} = riakc_pb_socket:start_link("db1.aidanstacey.com", 8087),
    register(db_pid, Pid).
%%--------------------------------------------------------------------
%% @private
%% @doc
%% Handling call messages
%%
%% @end
%%--------------------------------------------------------------------
-spec handle_call(Request::term(),From::pid(),State::term()) ->
                                  {reply,term(),term()} |
                                  {reply,term(),term(),integer()} |
                                  {noreply,term()} |
                                  {noreply,term(),integer()} |
                                  {stop,term(),term(),integer()} | 
                                  {stop,term(),term()}.
handle_call({request_location,Package_id},From,Db_PID) ->
    if 
        not is_binary(Package_id) ->
            {reply,{fail,invalid_key},Db_PID};
        true ->
            case Package_id =:= <<"">> of
                true ->
                    From ! {reply,{fail,empty_key},Db_PID};
                _ ->
                    Location_id = db_api:retrieve_data(<<"Packages">>,Package_id,Db_PID),
                    From ! {reply,db_api:retrieve_data(<<"Locations">>,Location_id,Db_PID),Db_PID}
            end
    end;
handle_call(stop,_From,_State) ->
        {stop,normal,
                replace_stopped,
          down}; %% setting the server's internal state to down
handle_call({Unknown,_},From,_Db_Pid) ->
    {reply,{fail,unknown_call,Unknown},From}.

%%--------------------------------------------------------------------
%% @private
%% @doc
%% Handling cast messages
%%
%% @end
%%--------------------------------------------------------------------
%% 
-spec handle_cast(Request::term(),From::pid(),State::term()) ->
    {reply,term(),term()} |
    {reply,term(),term(),integer()} |
    {noreply,term()} |
    {noreply,term(),integer()} |
    {stop,term(),term(),integer()} | 
    {stop,term(),term()}.
handle_cast({deliver,Package_id},_From,Db_PID) ->
    if 
        not is_binary(Package_id) ->
            {reply,{fail,invalid_key},Db_PID};
        true ->
            case Package_id =:= <<"">> of
                true ->
                    {reply,{fail,empty_key},Db_PID};
                _ ->
                    {reply,db_api:store_data(<<"Packages">>,Package_id,<<"Delivered">>,Db_PID),Db_PID}
            end
    end;
handle_cast({transfer_package,Package_id,Location_id},_From,Db_PID) ->
    if 
        not is_binary(Package_id) ->
            {reply,{fail,invalid_key},Db_PID};
        true ->
            if 
                not is_binary(Location_id) ->
                    {reply,{fail,invalid_value},Db_PID};
                true ->
                    case Package_id =:= <<"">> of
                        true ->
                            {reply,{fail,empty_key},Db_PID};
                        _ ->
                            case Location_id =:= <<"">> of
                                true -> 
                                    {reply,{fail,empty_value},Db_PID};
                                _ ->
                                    {reply,db_api:store_data(<<"Packages">>,Package_id,Location_id,Db_PID),Db_PID}
                            end
                    end
            end
    end;
handle_cast({update_location,Location_id,{Lat,Long}},_From,Db_PID) ->
    if 
        not is_binary(Location_id) ->
            {reply,{fail,invalid_key},Db_PID};
        true ->
            if
                not is_float(Lat) orelse not is_float(Long) ->
                    {reply,{fail,invalid_location,Location_id},Db_PID};
                true ->
                    Out_of_range = (Lat > 90) orelse (Lat < -90) orelse (Long > 180) orelse (Long < -180),
                    case Location_id =:= <<"">> of
                        true ->
                            {reply,{fail,empty_key},Db_PID};
                        _ ->
                            case Out_of_range of
                                true -> 
                                    {reply,{fail,invalid_location,Location_id},Db_PID};
                                _ ->
                                    {reply,db_api:store_data(<<"Locations">>,Location_id,term_to_binary({Lat,Long}),Db_PID),Db_PID}
                            end
                    end
            end
    end;
handle_cast(stop,_From,_State) ->
    {stop,normal,replace_stopped,down};
handle_cast({Unknown,_},From,_Db_Pid) ->
    {reply,{fail,unknown_cast_2,Unknown},From};
handle_cast({Unknown,_,_},From,_Db_Pid) ->
    {reply,{fail,unknown_cast_3,Unknown},From}.
handle_cast(_, _) ->
    {reply,{fail,unknown_cast}}.

%%--------------------------------------------------------------------
%% @private
%% @doc
%% Handling all non call/cast messages
%%
%% @end
-spec handle_info(Info::term(),State::term()) -> {noreply,term()} |
                                   {noreply,term(),integer()} |
                                   {stop,term(),term()}.
handle_info(_Info,State) ->
    {noreply,State}.

%%--------------------------------------------------------------------
%% @private
%% @doc
%% This function is called by a gen_server when it is about to
%% terminate. It should be the opposite of Module:init/1 and do any
%% necessary cleaning up. When it returns,the gen_server terminates
%% with Reason. The return value is ignored.
%%
%% @end
%%--------------------------------------------------------------------
-spec terminate(Reason::term(),term()) -> term().
terminate(_Reason,_State) ->
    ok.
    
%%--------------------------------------------------------------------
%% @private
%% @doc
%% Convert process state when code is changed
%%
%% @end
%%--------------------------------------------------------------------
-spec code_change(term(),term(),term()) -> {ok,term()}.
code_change(_OldVsn,State,_Extra) ->
    {ok,State}.
    
%%%===================================================================
%%% Internal functions
%%%===================================================================



-ifdef(EUNIT).
%%
%% Unit tests go here. 
%%
-include_lib("eunit/include/eunit.hrl").

%%% This test is working. 
request_location_test_() ->
    {setup,
     fun() -> % This setup fun is run once before the tests are run. If you want setup and teardown to run for each test, change {setup to {foreach
        meck:new(db_api),
        meck:expect(db_api,retrieve_data,fun(_Table,Key,_PID) -> {Key,"data"} end)

     end,
     fun(_) -> % This is the teardown fun. Notice it takes one, ignored in this example,parameter.
        meck:unload(db_api)
     end,
    [% This is the list of tests to be generated and run.
        % Test: Correct Inputs
        ?_assertEqual({reply,{{<<"package_1">>,"data"},"data"},some_Db_PID}, % Correct Input
                        mock:handle_call({request_location,<<"package_1">>},some_from_pid,some_Db_PID)),
        ?_assertEqual({reply,{{<<"package_2">>,"data"},"data"},some_Db_PID}, % Correct Input
                        mock:handle_call({request_location,<<"package_2">>},some_from_pid,some_Db_PID)),
        % Test: Invalid Key
        ?_assertEqual({reply,{fail,empty_key},some_Db_PID}, % Empty Key
                        mock:handle_call({request_location,<<"">>},some_from_pid,some_Db_PID)),
        ?_assertEqual({reply,{fail,invalid_key},some_Db_PID}, % Invalid Key Type
                        mock:handle_call({request_location,invalid},some_from_pid,some_Db_PID)),
        ?_assertEqual({reply,{fail,invalid_key},some_Db_PID}, % Invalid Key Type
                        mock:handle_call({request_location,12345},some_from_pid,some_Db_PID)),
        ?_assertEqual({reply,{fail,invalid_key},some_Db_PID}, % Invalid Key Type
                        mock:handle_call({request_location,"invalid"},some_from_pid,some_Db_PID))
    ]}.

deliver_test_() ->
    {setup,
        fun() -> % This setup fun is run once before the tests are run. If you want setup and teardown to run for each test, change {setup to {foreach
        meck:new(db_api),
        meck:expect(db_api,store_data,fun(Table,Key,Value,_PID) -> {Table,{Key,Value}} end)

        end,
        fun(_) -> % This is the teardown fun. Notice it takes one, ignored in this example, parameter.
        meck:unload(db_api)
        end,
    [% This is the list of tests to be generated and run.
        % Test: Correct Inputs
        ?_assertEqual({reply,{<<"Packages">>,{<<"package_1">>,<<"Delivered">>}},some_Db_PID}, % Correct Input
                        mock:handle_cast({deliver,<<"package_1">>},some_from_pid,some_Db_PID)),
        ?_assertEqual({reply,{<<"Packages">>,{<<"package_2">>,<<"Delivered">>}},some_Db_PID}, % Correct Input
                        mock:handle_cast({deliver,<<"package_2">>},some_from_pid,some_Db_PID)),
        % Test: Invalid Key
        ?_assertEqual({reply,{fail,empty_key},some_Db_PID}, % Empty Key
                        mock:handle_cast({deliver,<<"">>},some_from_pid,some_Db_PID)),             
        ?_assertEqual({reply,{fail,invalid_key},some_Db_PID}, % Invalid Key Type
                        mock:handle_cast({deliver,invalid},some_from_pid,some_Db_PID)),
        ?_assertEqual({reply,{fail,invalid_key},some_Db_PID}, % Invalid Key Type
                        mock:handle_cast({deliver,12345},some_from_pid,some_Db_PID)),
        ?_assertEqual({reply,{fail,invalid_key},some_Db_PID}, % Invalid Key Type
                        mock:handle_cast({deliver,"invalid"},some_from_pid,some_Db_PID))
    ]}.

transfer_package_test_() ->
    {setup,
        fun() -> % This setup fun is run once before the tests are run. If you want setup and teardown to run for each test, change {setup to {foreach
        meck:new(db_api),
        meck:expect(db_api,store_data,fun(Table,Key,Value,_PID) -> {Table,{Key,Value}} end)

        end,
        fun(_) -> % This is the teardown fun. Notice it takes one, ignored in this example, parameter.
        meck:unload(db_api)
        end,
    [% This is the list of tests to be generated and run.
        % Test: Correct Inputs
        ?_assertEqual({reply,{<<"Packages">>,{<<"package_1">>,<<"location_1">>}},some_Db_PID}, % Correct Input
                        mock:handle_cast({transfer_package,<<"package_1">>,<<"location_1">>},some_from_pid,some_Db_PID)),
        ?_assertEqual({reply,{<<"Packages">>,{<<"package_1">>,<<"location_2">>}},some_Db_PID}, % Correct Input
                        mock:handle_cast({transfer_package,<<"package_1">>,<<"location_2">>},some_from_pid,some_Db_PID)),
        % Test: Empty Argument
        ?_assertEqual({reply,{fail,empty_key},some_Db_PID}, % Empty Key
                        mock:handle_cast({transfer_package,<<"">>,<<"location_1">>},some_from_pid,some_Db_PID)),
        ?_assertEqual({reply,{fail,empty_key},some_Db_PID}, % Empty Key and Value
                        mock:handle_cast({transfer_package,<<"">>,<<"">>},some_from_pid,some_Db_PID)),
        ?_assertEqual({reply,{fail,empty_value},some_Db_PID}, % Empty Value
                        mock:handle_cast({transfer_package,<<"package_1">>,<<"">>},some_from_pid,some_Db_PID)),
        % Test: Invalid Key
        ?_assertEqual({reply,{fail,invalid_key},some_Db_PID}, % Invalid Key Type
                        mock:handle_cast({transfer_package,invalid,<<"location_1">>},some_from_pid,some_Db_PID)),
        ?_assertEqual({reply,{fail,invalid_key},some_Db_PID}, % Invalid Key Type
                        mock:handle_cast({transfer_package,12345,<<"location_1">>},some_from_pid,some_Db_PID)),
        ?_assertEqual({reply,{fail,invalid_key},some_Db_PID}, % Invalid Key Type
                        mock:handle_cast({transfer_package,"invalid",<<"location_1">>},some_from_pid,some_Db_PID)),
        % Test: Invalid Value
        ?_assertEqual({reply,{fail,invalid_value},some_Db_PID}, % Invalid Value Type
                        mock:handle_cast({transfer_package,<<"package_1">>,invalid},some_from_pid,some_Db_PID)),
        ?_assertEqual({reply,{fail,invalid_value},some_Db_PID}, % Invalid Value Type
                        mock:handle_cast({transfer_package,<<"package_1">>,12345},some_from_pid,some_Db_PID)),
        ?_assertEqual({reply,{fail,invalid_value},some_Db_PID}, % Invalid Value Type
                        mock:handle_cast({transfer_package,<<"package_1">>,"invalid"},some_from_pid,some_Db_PID))
]}.

update_location_test_() ->
    {setup,
        fun() -> % This setup fun is run once before the tests are run. If you want setup and teardown to run for each test, change {setup to {foreach
        meck:new(db_api),
        meck:expect(db_api,store_data,fun(Table,Key,Value,_PID) -> {Table,{Key,Value}} end)

        end,
        fun(_) -> % This is the teardown fun. Notice it takes one, ignored in this example, parameter.
        meck:unload(db_api)
        end,
    [% This is the list of tests to be generated and run.
        % Test: Correct Inputs
        ?_assertEqual({reply,{<<"Locations">>,{<<"location_1">>,{43.0,111.0}}},some_Db_PID}, % Correct Input
                        mock:handle_cast({update_location,<<"location_1">>,{43.0,111.0}},some_from_pid,some_Db_PID)),
        ?_assertEqual({reply,{<<"Locations">>,{<<"location_1">>,{44.0,112.0}}},some_Db_PID}, % Correct Input
                        mock:handle_cast({update_location,<<"location_1">>,{44.0,112.0}},some_from_pid,some_Db_PID)),
        % Test: Invalid Key -> 
        ?_assertEqual({reply,{fail,empty_key},some_Db_PID}, % Empty Key
                        mock:handle_cast({update_location,<<"">>,{43.0,111.0}},some_from_pid,some_Db_PID)),
        ?_assertEqual({reply,{fail,invalid_key},some_Db_PID}, % Invalid Key Type
                        mock:handle_cast({update_location,invalid,{43.0,181.0}},some_from_pid,some_Db_PID)),
        ?_assertEqual({reply,{fail,invalid_key},some_Db_PID}, % Invalid Key Type
                        mock:handle_cast({update_location,12345,{43.0,181.0}},some_from_pid,some_Db_PID)),
        ?_assertEqual({reply,{fail,invalid_key},some_Db_PID}, % Invalid Key Type
                        mock:handle_cast({update_location,"invalid",{43.0,181.0}},some_from_pid,some_Db_PID)),
        % Test: Invalid Latitude -> 
        ?_assertEqual({reply,{fail,invalid_location,<<"truck_1">>},some_Db_PID}, % Out Of Range
                        mock:handle_cast({update_location,<<"truck_1">>,{-91.0,111.0}},some_from_pid,some_Db_PID)),
        ?_assertEqual({reply,{fail,invalid_location,<<"truck_1">>},some_Db_PID}, % Out of Range  
                        mock:handle_cast({update_location,<<"truck_1">>,{91.0,111.0}},some_from_pid,some_Db_PID)),
        ?_assertEqual({reply,{fail,invalid_location,<<"truck_2">>},some_Db_PID}, % Invalid Latitude Type 
                        mock:handle_cast({update_location,<<"truck_2">>,{invalid,181.0}},some_from_pid,some_Db_PID)),
        ?_assertEqual({reply,{fail,invalid_location,<<"truck_2">>},some_Db_PID}, % Invalid Latitude Type 
                        mock:handle_cast({update_location,<<"truck_2">>,{<<"invalid">>,181.0}},some_from_pid,some_Db_PID)),
        ?_assertEqual({reply,{fail,invalid_location,<<"truck_2">>},some_Db_PID}, % Invalid Latitude Type 
                        mock:handle_cast({update_location,<<"truck_2">>,{"invalid",181.0}},some_from_pid,some_Db_PID)),
        % Test: Invalid Longitude -> 
        ?_assertEqual({reply,{fail,invalid_location,<<"truck_2">>},some_Db_PID}, % Out Of Range
                        mock:handle_cast({update_location,<<"truck_2">>,{43.0,-181.0}},some_from_pid,some_Db_PID)),
        ?_assertEqual({reply,{fail,invalid_location,<<"truck_2">>},some_Db_PID}, % Out Of Range
                        mock:handle_cast({update_location,<<"truck_2">>,{43.0,181.0}},some_from_pid,some_Db_PID)),
        ?_assertEqual({reply,{fail,invalid_location,<<"truck_2">>},some_Db_PID}, % Invalid Longitude Type 
                        mock:handle_cast({update_location,<<"truck_2">>,{43.0,invalid}},some_from_pid,some_Db_PID)),
        ?_assertEqual({reply,{fail,invalid_location,<<"truck_2">>},some_Db_PID}, % Invalid Longitude Type
                        mock:handle_cast({update_location,<<"truck_2">>,{43.0,<<"invalid">>}},some_from_pid,some_Db_PID)),
        ?_assertEqual({reply,{fail,invalid_location,<<"truck_2">>},some_Db_PID}, % Invalid Longitude Type
                        mock:handle_cast({update_location,<<"truck_2">>,{43.0,"invalid"}},some_from_pid,some_Db_PID))
    ]}.

unknown_call_test_() ->
    [% This is the list of tests to be generated and run.
        % Test: Unknown Call
        ?_assertEqual({reply,{fail,unknown_call,idk_1},some_from_pid}, % Unknown Call
                        mock:handle_call({idk_1,doesntmatter},some_from_pid,some_Db_PID)),
        ?_assertEqual({reply,{fail,unknown_call,idk_2},some_from_pid}, % Unknown Call
                        mock:handle_call({idk_2,doesntmatter},some_from_pid,some_Db_PID)),
        ?_assertEqual({reply,{fail,unknown_call,idk_3},some_from_pid}, % Unknown Call
                        mock:handle_call({idk_3,doesntmatter},some_from_pid,some_Db_PID))
    ].

unknown_cast_test_() ->
    [% This is the list of tests to be generated and run.
        % Test: Unknown Cast (2 arguments)
        ?_assertEqual({reply,{fail,unknown_cast_2,idk_1},some_from_pid}, % Unknown Cast
                        mock:handle_cast({idk_1,doesntmatter},some_from_pid,some_Db_PID)),
        ?_assertEqual({reply,{fail,unknown_cast_2,idk_2},some_from_pid}, % Unknown Cast
                        mock:handle_cast({idk_2,doesntmatter},some_from_pid,some_Db_PID)),
        ?_assertEqual({reply,{fail,unknown_cast_2,idk_3},some_from_pid}, % Unknown Cast
                        mock:handle_cast({idk_3,doesntmatter},some_from_pid,some_Db_PID)),
        ?_assertEqual({reply,{fail,unknown_cast_2,idk_4},some_from_pid}, % Unknown Cast
                        mock:handle_cast({idk_4,doesntmatter},some_from_pid,some_Db_PID)),
        % Test: Unknown Cast (3 arguments)
        ?_assertEqual({reply,{fail,unknown_cast_3,idk_1},some_from_pid}, % Unknown Cast
                        mock:handle_cast({idk_1,doesntmatter,doesntmatter},some_from_pid,some_Db_PID)),
        ?_assertEqual({reply,{fail,unknown_cast_3,idk_2},some_from_pid}, % Unknown Cast
                        mock:handle_cast({idk_2,doesntmatter,doesntmatter},some_from_pid,some_Db_PID)),
        ?_assertEqual({reply,{fail,unknown_cast_3,idk_3},some_from_pid}, % Unknown Cast
                        mock:handle_cast({idk_3,doesntmatter,doesntmatter},some_from_pid,some_Db_PID)),
        ?_assertEqual({reply,{fail,unknown_cast_3,idk_4},some_from_pid}, % Unknown Cast
                        mock:handle_cast({idk_4,doesntmatter,doesntmatter},some_from_pid,some_Db_PID))
    ].
    
-endif.
