// @flow

type LogLevel = "log" | "info" | "error" | "warn";

export type LogMessage = {
  level: LogLevel,
  tag: string,
  message: string,
  friendlyMessage?: string,
};

export function logMessage(log: LogMessage, uiLogger: ?(string) => void = undefined) {
  switch (log.level) {
    case 'log':
      console.log(log.message);
      break;
    case 'info':
      console.info(log.message);
      break;
    case 'error':
      console.error(log.message);
      break;
    case 'warn':
      console.warn(log.message);
      break;
    default:
      console.log(log.message);
      break;
  }

  if ((typeof log.friendlyMessage === 'string') && (uiLogger) && (typeof uiLogger !== 'undefined')) {
    uiLogger(log.friendlyMessage);
  }
}

