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
-export([init/1,request_hours_api/1,request_login_api/3,update_hours_api/3,
         update_login_api/2,get_hours/2,get_employees/3,handle_call/3,
         handle_cast/2,handle_info/2,terminate/2,code_change/3]).


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
-spec start()-> {ok,pid()} | ignore | {error,term()}.
start()->
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
-spec start(atom(),atom(),atom())-> {ok,pid()} | ignore | {error,term()}.
start(Registration_type,Name,Args)->
    gen_server:start_link({Registration_type,Name},?MODULE,Args,[]).


%%--------------------------------------------------------------------
%% @doc
%% Stops the server gracefully
%%
%% @end
%%--------------------------------------------------------------------
-spec stop()-> {ok} | {error,term()}.
stop()-> gen_server:call(?MODULE,stop).

%% Any other API functions go here.

request_hours_api(User_id)->
    Node = rrobin:next(),
    case gen_server:call(Node,{request_hours,User_id}) of
        {error,invalid_id}-> 500;
        {error,empty_id}-> 500;
        {error,notfound}-> 500;
        Response-> Response
    end.

request_login_api(_User_id,Username,Password)->
    Node = rrobin:next(),
    case gen_server:call(Node,{request_login,{Username,Password}}) of
        {error,invalid_id}-> 500;
        {error,empty_id}-> 500;
        {error,notfound}-> 500;
        Response-> Response
    end.

update_hours_api(User_id,Date,Hours)->
    Node = rrobin:next(),
    gen_server:cast(Node,{update_hours,{User_id,Date,Hours}}).

update_login_api(Username,New_password)->
    Node = rrobin:next(),
    gen_server:cast(Node,{update_login,{Username,New_password}}).


get_hours(Employee_id,Db_pid)->
    db_api:retrieve_data("Employees",Employee_id,Db_pid).

get_employees(Employees,Hours,_) when Employees =:= []->
    Hours;
get_employees(Employees,Hours,Db_pid)->
    [H|T] = Employees,
    Data = get_hours(H,Db_pid),
    get_employees(T,Hours ++ Data,Db_pid).


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
-spec init(term())-> {ok,term()} | {ok,term(),number()} | ignore | {stop,term()}.
init([])->
    case riakc_pb_socket:start_link("db1.aidanstacey.com",8087) of
        {ok,Db_pid}-> {ok,Db_pid};
        _-> {stop,link_failure}
    end.

%%--------------------------------------------------------------------
%% @private
%% @doc
%% Handling call messages
%%
%% @end
%%--------------------------------------------------------------------
-spec handle_call(Request::term(),From::pid(),State::term())->
                                  {reply,term(),term()}  |
                                  {reply,term(),term(),integer()}  |
                                  {noreply,term()}  |
                                  {noreply,term(),integer()}  |
                                  {stop,term(),term(),integer()} |
                                  {stop,term(),term()}.
handle_call({request_hours,User_id},_From,Db_pid)->
    if
        not is_list(User_id)->
            {reply,{error,invalid_id},Db_pid};
        true->
            case User_id =:= "" of
                true->
                    {reply,{error,empty_id},Db_pid};
                _->
                    [H|_] = User_id,
                    if
                        H =:= "W"->
                            {_,Employees,_} = db_api:retrieve_data("Employers",
                                                                User_id,
                                                                Db_pid),
                            if
                                is_list(Employees)->
                                    get_employees(Employees,[],Db_pid);
                                true->
                                    {reply,{error,invalid_id,Db_pid}}
                            end;
                        true->
                            get_hours(User_id,Db_pid)
                    end
            end
    end;
handle_call({request_login,{Username,Password}},_From,Db_pid)->
    if
        not is_list(Username)->
            {reply,{error,invalid_username},Db_pid};
        not is_list(Password)->
            {reply,{error,invalid_password},Db_pid};
        true->
            case Username =:= "" of
                true->
                    {reply,{error,empty_username},Db_pid};
                _->
                    {_,{Saved,User_id},_} = db_api:retrieve_data("Usernames",
                                                                Username,
                                                                Db_pid),
                    if
                        Saved =:= Password->
                            {reply,User_id,Db_pid};
                        true->
                            {reply,invalid_password,Db_pid}
                    end
            end
    end;
handle_call(stop,_From,_State)->
        {stop,normal,
                replace_stopped,
          down}; %% setting the server's internal state to down
handle_call({Unknown,_},From,_Db_pid)->
    {reply,{error,unknown_call,Unknown},From}.


%%--------------------------------------------------------------------
%% @private
%% @doc
%% Handling cast messages
%%
%% @end
%%--------------------------------------------------------------------
%%
handle_cast({update_hours,{User_id,Date,Hours}},Db_pid)->
    if
        not is_list(User_id)->
            io:format("update_hours: User_id is not a list."),
            {noreply,Db_pid};
        true->
            case User_id =:= "" of
                true->
                    io:format("update_hours: User_id is empty."),
                    {noreply,Db_pid};
                _->
                    db_api:store_data("Employees",User_id,{Date,Hours},
                                                Db_pid),
                    {noreply,Db_pid}
            end
    end;
handle_cast({update_login,{Username,New_password}},Db_pid)->
    if
        not is_list(Username)->
            io:format("update_login: Username is not a list."),
            {noreply,Db_pid};
        not is_list(New_password)->
            io:format("update_login: New_password is not a list."),
            {noreply,Db_pid};
        true->
            if
                Username =:= ""->
                    io:format("update_login: Username is empty."),
                    {noreply,Db_pid};
                New_password =:= ""->
                    io:format("update_login: New_password is empty."),
                    {noreply,Db_pid};
                true->
                    db_api:store_data("Locations",Username,New_password,Db_pid),
                    {noreply,Db_pid}
            end
    end;
handle_cast(_,Db_pid)->
    {noreply,Db_pid}.

%%--------------------------------------------------------------------
%% @private
%% @doc
%% Handling all non call/cast messages
%%
%% @end
-spec handle_info(Info::term(),State::term())-> {noreply,term()}  |
                                   {noreply,term(),integer()}  |
                                   {stop,term(),term()}.
handle_info(_Info,State)->
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
-spec terminate(Reason::term(),term())-> term().
terminate(_Reason,_State)->
    ok.

%%--------------------------------------------------------------------
%% @private
%% @doc
%% Convert process state when code is changed
%%
%% @end
%%--------------------------------------------------------------------
-spec code_change(term(),term(),term())-> {ok,term()}.
code_change(_OldVsn,State,_Extra)->
    {ok,State}.

