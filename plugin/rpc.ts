import { CommandEntry } from "./obsidian-types";

export const MSGPACK_TYPES = {
	Request: 0,
	Response: 1,
} as const;

export const FN_NAMES = {
	ListCmds: "list_cmds",
	RunCmd: "run_cmd",
} as const;

export type MsgpackType = typeof MSGPACK_TYPES[keyof typeof MSGPACK_TYPES];
export type FnName = typeof FN_NAMES[keyof typeof FN_NAMES];
export type MsgId = number;
export type MsgpackError = string[] | null;
export type DecodedMessagePackData<N extends MsgpackType, T extends unknown[]> = [N, MsgId, ...T];
export type RequestMessagePackData<Name extends FnName, Payload> = DecodedMessagePackData<typeof MSGPACK_TYPES["Request"], [Name, Payload]>;
export type ResponseMessagePackData<Payload> = DecodedMessagePackData<typeof MSGPACK_TYPES["Response"], [MsgpackError, Payload]>;

export interface ParsedRequest<FnName, Params> {
	id: MsgId;
	type: typeof MSGPACK_TYPES["Request"];
	fnName: FnName;
	params: Params;
}

export interface ParsedResponse<ResultData> {
	id: MsgId;
	type: typeof MSGPACK_TYPES["Response"];
	error: MsgpackError;
	result: ResultData;
}

export type ListCmdsRequest  = ParsedRequest<typeof FN_NAMES["ListCmds"], { includeNames: boolean; includeIcons: boolean; }>;
export type RunCmdRequest = ParsedRequest<typeof FN_NAMES["RunCmd"], { cmdId: string }>;

export type ListCmdsResponse = ParsedResponse<CommandEntry[]>;
export type RunCmdResponse = ParsedResponse<boolean>;

export type AnyRequest = ListCmdsRequest | RunCmdRequest;
export type AnyResponse = ListCmdsResponse | RunCmdResponse;
export type AnyData = AnyRequest | AnyResponse;

export function isResponseMessagePackData(
	data: DecodedMessagePackData<MsgpackType, unknown[]>
): data is ResponseMessagePackData<unknown[]> {
	if (data[0] !== MSGPACK_TYPES.Response) {
		return false;
	}

	if (data[2] !== null && !Array.isArray(data[2])) {
		return false;
	}

	return true;
}

export function isRequestMessagePackData(
	data: DecodedMessagePackData<MsgpackType, unknown[]>
): data is RequestMessagePackData<FnName, unknown[]> {
	if (data[0] !== MSGPACK_TYPES.Request) {
		return false;
	}

	if (typeof data[2] !== "string") {
		return false;
	}

	if (Object.values(FN_NAMES).indexOf(data[2] as FnName) === -1) {
		return false;
	}

	return true;
}

export function isDecodedMessagePackData(
	data: unknown
): data is DecodedMessagePackData<MsgpackType, unknown[]> {
	if (!Array.isArray(data)) {
		return false;
	}

	if (data.length !== 4) {
		return false;
	}

	if (typeof data[0] !== "number" || typeof data[1] !== "number") {
		return false;
	}

	if (Object.values(MSGPACK_TYPES).indexOf(data[0] as MsgpackType) === -1) {
		return false;
	}

	return true;
}

export function mapRPCResponse(response: AnyResponse): ResponseMessagePackData<unknown> {
	const { id, type, error, result } = response;
	return [type, id, error, result];
}

export function parseMessagePackRequest(request: RequestMessagePackData<FnName, unknown>): AnyRequest | Error {
	const [messageType, messageId, fnName, params] = request;
	switch (fnName) {
		case "list_cmds": {
			return <ListCmdsRequest>{
				id: messageId,
				type: messageType,
				fnName,
				params
			};
		}
		case "run_cmd": {
			return <RunCmdRequest>{
				id: messageId,
				type: messageType,
				fnName,
				params,
			};
		}
	}
}

export function parseMessagePackData(data: unknown): AnyData | Error {
	if (!isDecodedMessagePackData(data)) {
		return new Error("Invalid message pack data");
	}

	if (isRequestMessagePackData(data)) {
		return parseMessagePackRequest(data);
	}

	return new Error("Unknown message type");
}

