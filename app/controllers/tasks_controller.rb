# app/controllers/tasks_controller.rb
class TasksController < ApplicationController
  include ActionView::RecordIdentifier
  before_action :set_task, only: [:show, :edit, :update, :destroy, :modal]

  def index
    @tasks = Task.order(created_at: :desc)
  end

  def new
    @task = Task.new
    if turbo_frame_request?
      render partial: "tasks/form_modal", locals: { task: @task }, layout: false
    else
      render :new
    end
  end

  def create
    @task = Task.new(task_params)

    respond_to do |format|
      if @task.save
        format.turbo_stream do
          render turbo_stream: [
            turbo_stream.prepend("tasks", partial: "tasks/task", locals: { task: @task }),
            turbo_stream.update("task_modal", "")
          ]
        end
        format.html { redirect_to tasks_path, notice: "Task created.", status: :see_other }
      else
        format.turbo_stream do
          render turbo_stream: turbo_stream.replace(
            "task_modal",
            partial: "tasks/form_modal",
            locals: { task: @task }
          )
        end
        format.html { render :new, status: :unprocessable_entity }
      end
    end
  end

  def edit
    if turbo_frame_request?
      render partial: "tasks/form_modal", locals: { task: @task }, layout: false
    else
      render :edit
    end
  end

  def update
    respond_to do |format|
      if @task.update(task_params)
        format.turbo_stream do
          render turbo_stream: [
            turbo_stream.replace(dom_id(@task), partial: "tasks/task", locals: { task: @task }),
            turbo_stream.update("task_modal", "")
          ]
        end
        format.html { redirect_to tasks_path, notice: "Task updated.", status: :see_other }
        format.json { head :no_content }
      else
        format.turbo_stream do
          render turbo_stream: turbo_stream.replace(
            "task_modal",
            partial: "tasks/form_modal",
            locals: { task: @task }
          )
        end
        format.html { render :edit, status: :unprocessable_entity }
        format.json { render json: { errors: @task.errors.full_messages }, status: :unprocessable_entity }
      end
    end
  end

  def show
    if turbo_frame_request?
      render partial: "tasks/show_modal", locals: { task: @task }, layout: false
    else
      # render full page if you have one
    end
  end

  # GET /tasks/:id/modal
  def modal
    render partial: "tasks/show_modal", locals: { task: @task }, layout: false
  end

  def destroy
    @task.destroy
    respond_to do |format|
      format.turbo_stream { render turbo_stream: turbo_stream.remove(dom_id(@task)) }
      format.html { redirect_to tasks_path, notice: "Task deleted.", status: :see_other }
    end
  end

  # GET /tasks/calendar
  def calendar
    # Renders calendar view
  end

  # GET /tasks/events
  def events
    range_start = params[:start].presence && Time.zone.parse(params[:start]) rescue nil
    range_end   = params[:end].presence && Time.zone.parse(params[:end]) rescue nil

    scope = Task.all
    if range_start && range_end
      scope = scope.where(due_date: range_start..range_end)
    elsif range_start
      scope = scope.where('due_date >= ?', range_start)
    elsif range_end
      scope = scope.where('due_date <= ?', range_end)
    end

    events = scope.map do |t|
      {
        id: t.id,
        title: t.title,
        start: t.due_date&.iso8601,
        allDay: true,
        url: Rails.application.routes.url_helpers.modal_task_path(t)
      }
    end

    respond_to do |format|
      format.json { render json: events }
      format.html { head :not_acceptable }
    end
  end

  private
  def set_task; @task = Task.find(params[:id]); end
  def task_params; params.require(:task).permit(:title, :description, :status, :due_date, :priority); end
end
