# frozen_string_literal: true

class PlansController < ApplicationController
  def current
    state = PlanPresenter.new(session_plan: session[:plan]).call
    session[:plan] ||= state.session_payload
    @start_date = state.start_date
    @end_date   = state.end_date
    @slots      = state.slots
  end

  def generate
    start_date = Date.parse(params[:start_date])
    end_date   = Date.parse(params[:end_date])

    session[:plan] = {
      "start_date"   => start_date.iso8601,
      "end_date"     => end_date.iso8601,
      "external_ids" => PlanPresenter.new.sample_ids(start_date: start_date, end_date: end_date)
    }

    redirect_to root_path
  end
end
