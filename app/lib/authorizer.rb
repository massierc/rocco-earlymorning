require 'google/apis/sheets_v4'
require 'googleauth'
require 'googleauth/stores/file_token_store'
require 'fileutils'
require_relative '../models/user'

class Authorizer
  include Utils

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
    if Rails.env.production?
      @credentials_path = File.join('/home/gildo/apps/rocco/shared/credentials/', "#{@uid}.yaml")
    else
      @credentials_path = File.join(File.dirname(__FILE__), '../../credentials/', "#{@uid}.yaml")
    end
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
    @credentials.fetch_access_token!({}) if @credentials.expired?
    service = Google::Apis::SheetsV4::SheetsService.new
    service.client_options.application_name = application_name
    service.authorization = @credentials

    service
  end

  def update_timesheet(user = @tg_user)
    day_column = find_current_workday(workday_cells).to_s26.upcase
    project_row = find_project_cell(project_cells, user.who, user.what)
    service.update_spreadsheet_value(user.sheet_id, "#{this_month_sheet}!#{day_column}#{project_row}", values(user.howmuch), value_input_option: 'USER_ENTERED')
    user.last_cell = "#{day_column}#{project_row}"
    user.save!
  end

  def create_note(user = @tg_user, note)
    sheets = service.get_spreadsheet(user.sheet_id).sheets
    sheet_id = sheets.find {|s| s.properties.title == this_month_sheet}.properties.sheet_id

    requests = []
    requests.push(
      repeat_cell: {
        range: user.last_cell.to_sheet_range(sheet_id),
        cell: {
          note: note
        },
        fields: "note"
      }
    )

    body = {requests: requests}
    service.batch_update_spreadsheet(user.sheet_id, body, {})
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

  def project_cells(sheet_id = @tg_user.sheet_id, prevent_loop=false)
    begin
      return if service == 0
      if @tg_user.is_emf?
        projects = service.get_spreadsheet_values(sheet_id, "#{this_month_sheet}!B:C").values
      else
        projects = service.get_spreadsheet_values(sheet_id, "#{this_month_sheet}!B:B").values
      end
    rescue Google::Apis::ClientError => e
      if e.message.include?('Unable to parse range') && !prevent_loop
        generate_this_month_timesheet
        project_cells(prevent_loop=true)
      end
      return false
    end
    projects
  end

  def generate_this_month_timesheet(sheet_id = @tg_user.sheet_id)
    sheets = service.get_spreadsheet(sheet_id).sheets
    template_sheet = sheets.find { |s| s.properties.title == "Template"}
    return unless template_sheet
    template_sheet_id = template_sheet.properties.sheet_id
    requests = []
    requests.push(
      duplicate_sheet: {
        new_sheet_name: this_month_sheet,
        source_sheet_id: template_sheet_id
      })

    body = {requests: requests}

    service.batch_update_spreadsheet(sheet_id, body, {})
  end

  def list_projects(cells)
    begin
      cells = cells.map{|x| x[0]}[0..-2].compact.uniq
      cells = cells.each_slice(2).to_a
    rescue
      return ["stop"]
    end
  end

  def list_activities(cells, project)
    if cells
      cells = cells.select{|m| m.include?(project)}.map{|x| x[-1]} << "stop"
      cells = cells.each_slice(4).to_a
    else
      [["stop"]]
    end
  end

  def find_project_cell(cells, project, activity)
    if @tg_user.is_emf?
      project_exists = cells.any? { |c| c.include? project }
      activity_exists = cells.any? { |c| c.include? activity }

      cell = if project != activity
        cells.find_index { |arr| arr == [project, activity] }
      else
        same_name_project_and_activity = cells.find_index { |arr| arr == [project, activity] }
        if same_name_project_and_activity
          same_name_project_and_activity
        else
          cells.find_index { |arr| arr.compact == [project] }
        end
      end

      if cell
        return cell += 1
      else
        data = {
          project: {
            exists: project_exists,
            value: project
          },
          activity: {
            exists: activity_exists,
            value: activity
          }
        }
        create_missing_row(@tg_user, data)
        find_project_cell(project_cells, project, activity)
      end
    else
      cell = cells.index([project])
      return cell += 1 if cell
      data = {
        project: {
          exists: false,
          value: project
        }
      }
      Telegram.bot.send_message(chat_id: @tg_user.uid, text: "Sto aggiungendo il nuovo cliente...")
      create_missing_row(@tg_user, data)
      find_project_cell(project_cells, project, nil)
    end
  end

  def create_missing_column(user = @tg_user, workdays, column)
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
    service.batch_update_spreadsheet(user.sheet_id, body, {})
    service.update_spreadsheet_value(user.sheet_id, "#{this_month_sheet}!#{cell_index.to_s26.upcase}1", values(column), value_input_option: 'USER_ENTERED')
  end


  def create_missing_row(user = @tg_user, data)
    sheets = service.get_spreadsheet(user.sheet_id).sheets
    sheet_id = sheets.find { |s| s.properties.title == this_month_sheet }.properties.sheet_id

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
          end_index: cell_index + 1
        },
        inherit_before: true
      })

    body = { requests: requests }

    service.batch_update_spreadsheet(user.sheet_id, body, {})

    name = service.get_spreadsheet_values(user.sheet_id, "#{this_month_sheet}!A2").values[0][0]
    user.name = name
    user.save

    cell_index += 1

    service.update_spreadsheet_value(user.sheet_id, "#{this_month_sheet}!A#{cell_index}", values(name), value_input_option: 'USER_ENTERED')
    service.update_spreadsheet_value(user.sheet_id, "#{this_month_sheet}!B#{cell_index}", values(data[:project][:value]), value_input_option: 'USER_ENTERED')
    service.update_spreadsheet_value(user.sheet_id, "#{this_month_sheet}!C#{cell_index}", values(data[:activity][:value]), value_input_option: 'USER_ENTERED') if @tg_user.is_emf?
    service.update_spreadsheet_value(user.sheet_id, "#{this_month_sheet}!D#{cell_index}", values("=SUM(E#{cell_index}:AL#{cell_index})"), value_input_option: 'USER_ENTERED')

    requests = []

    requests.push({
      repeat_cell: {
        range: {
          sheet_id: sheet_id,
          start_row_index: cell_index-1,
          end_row_index: cell_index,
          start_column_index: 1,
          end_column_index: 2
        },
        cell: {
          user_entered_format: {
            text_format: {
              foreground_color: {
                red: 1.0,
                green: 0.0,
                blue: 0.0
              },
              bold: true
            }
          }
        },
        fields: "userEnteredFormat(textFormat)"
      }
    })
    body = {requests: requests}
    service.batch_update_spreadsheet(user.sheet_id, body, {})
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
