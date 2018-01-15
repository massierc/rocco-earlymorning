require 'google/apis/sheets_v4'
require 'googleauth'
require 'googleauth/stores/file_token_store'
require 'fileutils'
require_relative '../models/user'

class Authorizer
  attr_reader :username
  attr_reader :authorizer
  attr_reader :credentials
  attr_reader :oob_uri
  attr_reader :user_id
  attr_reader :application_name
  attr_reader :credentials_path
  attr_accessor :tg_user

  def initialize(uid)
    @uid = uid

    @oob_uri = 'urn:ietf:wg:oauth:2.0:oob'
    @application_name = 'Aurora'

    client_secrets_path = File.join(File.dirname(__FILE__), '../../config/client_secret.json')
    @credentials_path = File.join(File.dirname(__FILE__), '../../credentials/', "#{@uid}.yaml")
    scope = Google::Apis::SheetsV4::AUTH_SPREADSHEETS
    FileUtils.mkdir_p(File.dirname(@credentials_path))
    client_id = Google::Auth::ClientId.from_file(client_secrets_path)
    token_store = Google::Auth::Stores::FileTokenStore.new(file: @credentials_path)
    @authorizer = Google::Auth::UserAuthorizer.new(client_id, scope, token_store)
    @user_id = 'default'
    @credentials = @authorizer.get_credentials(@user_id)
    @tg_user = User.find_by_uid(@uid)
  end

  def get_url
    File.delete(credentials_path) if File.exist?(credentials_path)
    @authorizer.get_authorization_url(base_url: @oob_uri)
  end

  def store_auth(code)
    if @credentials.nil?
      begin
        authorizer.get_and_store_credentials_from_code(user_id: @user_id, code: code, base_url: @oob_uri)
      rescue Signet::AuthorizationError
        return 0
      end
    end
  end

  def service
    begin
      @credentials.fetch_access_token!({}) if @credentials.expired?
      service = Google::Apis::SheetsV4::SheetsService.new
      service.client_options.application_name = application_name
      service.authorization = @credentials

      service
    rescue
      return 0
    end
  end

  def update_timesheet(user = @tg_user)
    day_column = find_current_workday(workday_cells).to_s26.upcase
    project_row = find_project_cell(project_cells, user.who, user.what)

    service.update_spreadsheet_value(user.sheet_id, "#{this_month_sheet}!#{day_column}#{project_row}", values(user.howmuch), value_input_option: 'USER_ENTERED')
  end

  def workday_cells(user = @tg_user)
    begin
      service.get_spreadsheet_values(user.sheet_id, "#{this_month_sheet}!1:1").values.flatten
    rescue Google::Apis::ClientError
      return false
    end

  end

  def find_current_workday(workdays, i=0)
    today = Date.today.day.to_s
    cell = workdays.find_index(today)
    if cell
      return cell + 1
    else
      create_missing_column(@tg_user, workdays, today) if i == 0
      find_current_workday(workday_cells, i = 1)
    end
  end

  def find_next_workday(workdays)
    workdays[find_current_workday(workdays)]
  end

  def this_month_sheet

    convert = {
      "January": "Gennaio",
      "February": "Febbraio",
      "March": "Marzo",
      "April": "Aprile",
      "May": "Maggio",
      "June": "Giugno",
      "July": "Luglio",
      "August": "Agosto",
      "September": "Settembre",
      "October": "Ottobre",
      "November": "Novembre",
      "December": "Dicembre"
    }

    date = Date.today.strftime("%B %Y").split
    month = convert[(date[0].to_sym)]
    (month + " " + date.last)
  end

  def project_cells(user = @tg_user)

    begin
      projects = service.get_spreadsheet_values(user.sheet_id, "#{this_month_sheet}!B:C").values
    rescue Google::Apis::ClientError
      return false
    end

    projects
  end

  def list_projects(cells)
    begin
      cells = cells.map{|x| x[0]}[0..-2].compact.uniq
      cells << "stop"
      cells = cells.each_slice(4).to_a
    rescue
      return ["stop"]
    end
  end

  def list_activities(cells, project)
    cells.select{|m| m.include?(project)}.map{|x| x[-1]} << "stop"
  end

  def find_project_cell(cells, project, activity)
    project_exists = cells.any?{|c| c.include? project}
    activity_exists = cells.any?{|c| c.include? activity}

    cell = if project != activity
      cells.find_index { |arr| arr == [project, activity] }
    else
      cells.find_index { |arr| arr.compact == [project] }
    end

    if cell
      return cell += 1
    else
      data = {
        project: {
          exists: project_exists, value: project
        },
        activity: {
          exists: activity_exists, value: activity
        }
      }
      create_missing_row(@tg_user, data)
      find_project_cell(project_cells, project, activity)
    end
  end

  def create_missing_column(user = @tg_user, workdays, column)
    this_month_sheet = I18n.l(Date.today, locale: 'it', format: :sheet).capitalize
    sheets = service.get_spreadsheet(user.sheet_id).sheets
    sheet_id = sheets.find { |s| s.properties.title == this_month_sheet }.properties.sheet_id

    workdays << column
    cell_index = workdays.map(&:to_i).sort.find_index(column.to_i)

    requests = []
    requests.push(
      insert_dimension: {
        range: {
          sheet_id: sheet_id,
          dimension: 'COLUMNS',
          start_index: cell_index,
          end_index: cell_index+1
        },
        inherit_before: true
      }
    )

    body = {requests: requests}
    cell_index += 1
    result = service.batch_update_spreadsheet(user.sheet_id, body, {})
    service.update_spreadsheet_value(user.sheet_id, "#{this_month_sheet}!#{cell_index.to_s26.upcase}1", values(column), value_input_option: 'USER_ENTERED')
  end


  def create_missing_row(user = @tg_user, data)
    this_month_sheet = I18n.l(Date.today, locale: "it", format: :sheet).capitalize

    sheets = service.get_spreadsheet(user.sheet_id).sheets
    sheet_id = sheets.find {|s| s.properties.title == this_month_sheet}.properties.sheet_id

    if data[:project][:exists]
      cell_index = project_cells.find_index { |arr| arr.include? data[:project][:value] } + 1
    else
      cell_index = 3 # Dopo ferie/malattia
    end

    requests = []
    requests.push(
      insert_dimension: {
        range: {
          sheet_id: sheet_id,
          dimension: 'ROWS',
          start_index: cell_index,
          end_index: cell_index+1
        },
        inherit_before: true
      },
    )
    body = {requests: requests}

    result = service.batch_update_spreadsheet(user.sheet_id, body, {})

    name = service.get_spreadsheet_values(user.sheet_id, "#{this_month_sheet}!A2").values[0][0]

    cell_index += 1

    service.update_spreadsheet_value(user.sheet_id, "#{this_month_sheet}!A#{cell_index}", values(name), value_input_option: 'USER_ENTERED')
    service.update_spreadsheet_value(user.sheet_id, "#{this_month_sheet}!B#{cell_index}", values(data[:project][:value]), value_input_option: 'USER_ENTERED')
    service.update_spreadsheet_value(user.sheet_id, "#{this_month_sheet}!C#{cell_index}", values(data[:activity][:value]), value_input_option: 'USER_ENTERED')
    service.update_spreadsheet_value(user.sheet_id, "#{this_month_sheet}!D#{cell_index}", values("=SUM(E#{cell_index}:AL#{cell_index})"), value_input_option: 'USER_ENTERED')
  end

  def workday?(user = @tg_user)
    begin
      workdays = workday_cells
    rescue Google::Apis::ClientError
      return false
    end

    find_current_workday(workdays)

  end

  def values(value)
    @body = {"values": [ [ "#{value}" ] ] }
  end
end
