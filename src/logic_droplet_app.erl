%%%-------------------------------------------------------------------
%% @doc logic_droplet public API
%% @end
%%%-------------------------------------------------------------------

-module(logic_droplet_app).

-behaviour(application).

-export([start/2, stop/1]).

start(_StartType, _StartArgs) ->
    logic_droplet_sup:start_link().

stop(_State) ->
    ok.

%% internal functions
