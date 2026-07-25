import { SparkToolName, isAppleHealthReadTool } from './SparkToolName';

export enum ToolDataSensitivity {
  NONE = 'none',
  PERSONAL = 'personal',
  SENSITIVE = 'sensitive',
  REGULATED = 'regulated'
}

export enum ToolDataCategory {
  HEALTH = 'health',
  MEMBER = 'member',
  LOCATION = 'location',
  MEMORY = 'memory',
  KNOWLEDGE = 'knowledge',
  CALENDAR = 'calendar',
  PUBLIC_WEB = 'publicWeb',
  UI = 'ui',
  SYSTEM = 'system'
}

export enum ToolEgressPolicy {
  ALLOW = 'allow',
  REQUIRE_CONSENT = 'requireConsent',
  LOCAL_ONLY = 'localOnly'
}

export function dataCategoryForTool(tool: SparkToolName): ToolDataCategory {
  switch (tool) {
    case SparkToolName.FETCH_STEP_DETAILS:
    case SparkToolName.FETCH_ENERGY_DETAILS:
    case SparkToolName.FETCH_NUTRITION_DETAILS:
    case SparkToolName.MAKE_NUTRITION_DATA:
    case SparkToolName.FETCH_SLEEP_DETAILS:
    case SparkToolName.FETCH_WORKOUT_DETAILS:
    case SparkToolName.GENERATE_STRUCTURED_HEALTH_CARD:
    case SparkToolName.LIST_MEMBER_HEALTH_SOURCES:
    case SparkToolName.GET_HEALTH_RESOURCE_REFERENCE:
    case SparkToolName.GET_HEALTH_RESOURCE_CONTEXT:
      return ToolDataCategory.HEALTH;
    case SparkToolName.GET_CURRENT_MEMBER:
    case SparkToolName.REQUEST_MEMBER_SELECTION:
    case SparkToolName.SWITCH_MEMBER:
    case SparkToolName.FIND_MEMBER:
    case SparkToolName.QUERY_MEMBER_PROFILE:
      return ToolDataCategory.MEMBER;
    case SparkToolName.QUERY_LOCATION:
    case SparkToolName.GET_CURRENT_LOCATION:
    case SparkToolName.SEARCH_NEARBY_LOCATIONS:
    case SparkToolName.GET_ROUTE:
    case SparkToolName.QUERY_WEATHER:
      return ToolDataCategory.LOCATION;
    case SparkToolName.SAVE_MEMORY:
    case SparkToolName.RETRIEVE_MEMORY:
    case SparkToolName.UPDATE_MEMORY:
      return ToolDataCategory.MEMORY;
    case SparkToolName.SEARCH_KNOWLEDGE_BAG:
    case SparkToolName.CREATE_KNOWLEDGE_DOCUMENT:
      return ToolDataCategory.KNOWLEDGE;
    case SparkToolName.SEARCH_CALENDAR_AND_REMINDERS:
    case SparkToolName.WRITE_SYSTEM_EVENT:
      return ToolDataCategory.CALENDAR;
    case SparkToolName.SEARCH_ONLINE:
    case SparkToolName.READ_WEB_PAGE:
    case SparkToolName.SEARCH_ARXIV_PAPERS:
    case SparkToolName.EXTRACT_REMOTE_FILE_CONTENT:
      return ToolDataCategory.PUBLIC_WEB;
    case SparkToolName.SHOW_CUSTOM_MESSAGE_CARD:
    case SparkToolName.ASK_USER_QUESTION:
    case SparkToolName.SHOW_MEDICAL_RISK_NOTICE:
      return ToolDataCategory.UI;
    case SparkToolName.GENERATE_CHAT_TITLE:
    case SparkToolName.CREATE_CANVAS:
    case SparkToolName.EDIT_CANVAS:
    case SparkToolName.QUERY_TASKS_BY_MEMBER:
    case SparkToolName.GENERATE_TASK:
      return ToolDataCategory.SYSTEM;
    default:
      return ToolDataCategory.SYSTEM;
  }
}

export function declaredSensitivityForTool(tool: SparkToolName): ToolDataSensitivity {
  switch (dataCategoryForTool(tool)) {
    case ToolDataCategory.HEALTH:
      return ToolDataSensitivity.REGULATED;
    case ToolDataCategory.MEMBER:
    case ToolDataCategory.LOCATION:
    case ToolDataCategory.MEMORY:
    case ToolDataCategory.CALENDAR:
      return ToolDataSensitivity.PERSONAL;
    case ToolDataCategory.KNOWLEDGE:
      return ToolDataSensitivity.SENSITIVE;
    default:
      return ToolDataSensitivity.NONE;
  }
}

export function egressPolicyForTool(tool: SparkToolName): ToolEgressPolicy {
  const s = declaredSensitivityForTool(tool);
  if (s === ToolDataSensitivity.NONE) {
    return ToolEgressPolicy.ALLOW;
  }
  return ToolEgressPolicy.REQUIRE_CONSENT;
}

/** 运行时 Consent：仅五类 Apple Health 读工具（对齐 iOS AppleHealthToolConsentPolicy）。 */
export function runtimeRequiresAppleHealthConsent(
  toolName: string,
  sensitive: boolean,
  providerCompany: string | undefined,
  isAlwaysAllowed: boolean
): boolean {
  if (!sensitive) {
    return false;
  }
  if (!isAppleHealthReadTool(toolName)) {
    return false;
  }
  const company = (providerCompany ?? '').toUpperCase();
  if (company === 'LOCAL') {
    return false;
  }
  return !isAlwaysAllowed;
}
