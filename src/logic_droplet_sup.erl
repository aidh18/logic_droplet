%%%-------------------------------------------------------------------
%% @doc logic_droplet top level supervisor.
%% @end
%%%-------------------------------------------------------------------

-module(logic_droplet_sup).

-behaviour(supervisor).

-export([start_link/0]).

-export([init/1]).

-define(SERVER, ?MODULE).

start_link() ->
    supervisor:start_link({local, ?SERVER}, ?MODULE, []).

    init([]) ->
        %% Configuration options for all the supervised children.
            %% If a child process crashes, restart only that one (one_for_one).
            %% If there is more than 2 crashes ('intensity') in
            %% 3600 seconds ('period'), crash the supervisor and all
            %% its children.
            %%
            %% sup_flags() = #{strategy => strategy(),         % optional
            %%                 intensity => non_neg_integer(), % optional
            %%                 period => pos_integer()}        % optional
                SupFlags = #{strategy => one_for_all,
                         intensity => 2,
                         period => 3600},
            %% Specify a list of child processes. Each must including
            %% a unique id and the start function for the module.
            %% These children may be more supervisors, gen_servers,
            %% finite state machines (FSM), or other standard or custom
            %% OTP elements.
            ChildSpecList = [child(request_sup,supervisor)],
            {ok, {SupFlags, ChildSpecList}}.
        %% internal functions
        %%
        %%
        %%
        child(Module,Type)->
        %% child_spec() = #{id => child_id(),       % mandatory
        %%                  start => mfargs(),      % mandatory
        %%                  restart => restart(),   % optional
        %%                  shutdown => shutdown(), % optional
        %%                  type => worker(),       % optional
        %%                  modules => modules()}   % optional
                #{id => Module,
                  start => {Module,start_link,[]},
                  restart => permanent,
                  shutdown => 2000,
                  type => Type,
                  modules => [Module]}.
