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
    payload = PlanPresenter.new.generate_payload(
      start_date: parse_date(params[:start_date]),
      end_date: parse_date(params[:end_date])
    )

    if payload
      session[:plan] = payload
      redirect_to root_path
    else
      redirect_to root_path,
                  alert: "Couldn't generate a plan — pick a valid range of up to #{PlanPresenter::MAX_PLAN_DAYS} days."
    end
  end

  private

  def parse_date(value)
    Date.iso8601(value.to_s)
  rescue Date::Error
    nil
  end
end
