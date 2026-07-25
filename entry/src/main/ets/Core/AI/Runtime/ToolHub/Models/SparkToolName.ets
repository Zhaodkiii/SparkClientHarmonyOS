/**
 * 对齐 iOS SparkToolName：工具 rawValue 与服务端 / iOS 保持一致。
 */
export enum SparkToolName {
  FETCH_STEP_DETAILS = 'fetch_step_details',
  FETCH_ENERGY_DETAILS = 'fetch_energy_details',
  FETCH_NUTRITION_DETAILS = 'fetch_nutrition_details',
  MAKE_NUTRITION_DATA = 'make_nutrition_data',
  SHOW_MEDICAL_RISK_NOTICE = 'show_medical_risk_notice',
  FETCH_SLEEP_DETAILS = 'fetch_sleep_details',
  FETCH_WORKOUT_DETAILS = 'fetch_workout_details',
  GENERATE_STRUCTURED_HEALTH_CARD = 'generate_structured_health_card',
  LIST_MEMBER_HEALTH_SOURCES = 'list_member_health_sources',
  GET_HEALTH_RESOURCE_REFERENCE = 'get_health_resource_reference',
  GET_HEALTH_RESOURCE_CONTEXT = 'get_health_resource_context',
  SEARCH_KNOWLEDGE_BAG = 'search_knowledge_bag',
  CREATE_KNOWLEDGE_DOCUMENT = 'create_knowledge_document',
  SEARCH_CALENDAR_AND_REMINDERS = 'search_calendar_and_reminders',
  WRITE_SYSTEM_EVENT = 'write_system_event',
  QUERY_LOCATION = 'query_location',
  GET_CURRENT_LOCATION = 'get_current_location',
  SEARCH_NEARBY_LOCATIONS = 'search_nearby_locations',
  GET_ROUTE = 'get_route',
  QUERY_WEATHER = 'query_weather',
  SAVE_MEMORY = 'save_memory',
  RETRIEVE_MEMORY = 'retrieve_memory',
  UPDATE_MEMORY = 'update_memory',
  GENERATE_CHAT_TITLE = 'generate_chat_title',
  SHOW_CUSTOM_MESSAGE_CARD = 'show_custom_message_card',
  ASK_USER_QUESTION = 'ask_user_question',
  GET_CURRENT_MEMBER = 'get_current_member',
  REQUEST_MEMBER_SELECTION = 'request_member_selection',
  SWITCH_MEMBER = 'switch_member',
  FIND_MEMBER = 'find_member',
  QUERY_MEMBER_PROFILE = 'query_member_profile',
  SEARCH_ONLINE = 'search_online',
  READ_WEB_PAGE = 'read_web_page',
  SEARCH_ARXIV_PAPERS = 'search_arxiv_papers',
  EXTRACT_REMOTE_FILE_CONTENT = 'extract_remote_file_content',
  CREATE_CANVAS = 'create_canvas',
  EDIT_CANVAS = 'edit_canvas',
  QUERY_TASKS_BY_MEMBER = 'query_tasks_by_member',
  GENERATE_TASK = 'generate_task'
}

/** 联调专用，非 SparkToolName / 服务端目录。 */
export const DEBUG_ECHO_TOOL_NAME: string = 'debug_echo';

export const NO_SELECTION_SENTINEL: string = '__spark_tools_none__';

export function allSparkToolNames(): string[] {
  return [
    SparkToolName.FETCH_STEP_DETAILS,
    SparkToolName.FETCH_ENERGY_DETAILS,
    SparkToolName.FETCH_NUTRITION_DETAILS,
    SparkToolName.MAKE_NUTRITION_DATA,
    SparkToolName.SHOW_MEDICAL_RISK_NOTICE,
    SparkToolName.FETCH_SLEEP_DETAILS,
    SparkToolName.FETCH_WORKOUT_DETAILS,
    SparkToolName.GENERATE_STRUCTURED_HEALTH_CARD,
    SparkToolName.LIST_MEMBER_HEALTH_SOURCES,
    SparkToolName.GET_HEALTH_RESOURCE_REFERENCE,
    SparkToolName.GET_HEALTH_RESOURCE_CONTEXT,
    SparkToolName.SEARCH_KNOWLEDGE_BAG,
    SparkToolName.CREATE_KNOWLEDGE_DOCUMENT,
    SparkToolName.SEARCH_CALENDAR_AND_REMINDERS,
    SparkToolName.WRITE_SYSTEM_EVENT,
    SparkToolName.QUERY_LOCATION,
    SparkToolName.GET_CURRENT_LOCATION,
    SparkToolName.SEARCH_NEARBY_LOCATIONS,
    SparkToolName.GET_ROUTE,
    SparkToolName.QUERY_WEATHER,
    SparkToolName.SAVE_MEMORY,
    SparkToolName.RETRIEVE_MEMORY,
    SparkToolName.UPDATE_MEMORY,
    SparkToolName.GENERATE_CHAT_TITLE,
    SparkToolName.SHOW_CUSTOM_MESSAGE_CARD,
    SparkToolName.ASK_USER_QUESTION,
    SparkToolName.GET_CURRENT_MEMBER,
    SparkToolName.REQUEST_MEMBER_SELECTION,
    SparkToolName.SWITCH_MEMBER,
    SparkToolName.FIND_MEMBER,
    SparkToolName.QUERY_MEMBER_PROFILE,
    SparkToolName.SEARCH_ONLINE,
    SparkToolName.READ_WEB_PAGE,
    SparkToolName.SEARCH_ARXIV_PAPERS,
    SparkToolName.EXTRACT_REMOTE_FILE_CONTENT,
    SparkToolName.CREATE_CANVAS,
    SparkToolName.EDIT_CANVAS,
    SparkToolName.QUERY_TASKS_BY_MEMBER,
    SparkToolName.GENERATE_TASK
  ];
}

export function sparkToolNameFromRaw(raw: string): SparkToolName | undefined {
  const all = allSparkToolNames();
  for (let i = 0; i < all.length; i++) {
    if (all[i] === raw) {
      return raw as SparkToolName;
    }
  }
  return undefined;
}

export function isKnowledgeTool(name: string): boolean {
  return name === SparkToolName.SEARCH_KNOWLEDGE_BAG || name === SparkToolName.CREATE_KNOWLEDGE_DOCUMENT;
}

export function isWebSearchTool(name: string): boolean {
  return name === SparkToolName.SEARCH_ONLINE
    || name === SparkToolName.READ_WEB_PAGE
    || name === SparkToolName.SEARCH_ARXIV_PAPERS
    || name === SparkToolName.EXTRACT_REMOTE_FILE_CONTENT;
}

export function isAppleHealthReadTool(name: string): boolean {
  const n = name.trim().toLowerCase();
  return n === SparkToolName.FETCH_STEP_DETAILS
    || n === SparkToolName.FETCH_ENERGY_DETAILS
    || n === SparkToolName.FETCH_NUTRITION_DETAILS
    || n === SparkToolName.FETCH_SLEEP_DETAILS
    || n === SparkToolName.FETCH_WORKOUT_DETAILS;
}
