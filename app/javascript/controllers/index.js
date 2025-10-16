// Import and register all your controllers from the importmap via controllers/**/*_controller
import { application } from "controllers/application"
import { eagerLoadControllersFrom } from "@hotwired/stimulus-loading"
eagerLoadControllersFrom("controllers", application)

import GameFormController from "controllers/game_form_controller"
application.register("game-form", GameFormController)

import TournamentFormController from "controllers/tournament_form_controller"
application.register("tournament-form", TournamentFormController)

import DatetimePickerController from "controllers/datetime_picker_controller"
application.register("datetime-picker", DatetimePickerController)

import TabsController from "controllers/tabs_controller"
application.register("tabs", TabsController)

import StrategyController from "controllers/strategy_controller"
application.register("strategy", StrategyController)

import ModalController from "controllers/modal_controller"
application.register("modal", ModalController)

import PlaceAutocompleteController from "controllers/place_autocomplete_controller"
application.register("place-autocomplete", PlaceAutocompleteController)

import EloChartController from "controllers/elo_chart_controller"
application.register("elo-chart", EloChartController)
