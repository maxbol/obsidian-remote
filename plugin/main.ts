import { App, Editor, MarkdownView, Modal,  Plugin, PluginSettingTab, Setting } from 'obsidian';
import * as msgpack from "@msgpack/msgpack";
import * as net from "net";
import * as fs from "fs";
import {
	ListCmdsRequest,
	ListCmdsResponse,
	MSGPACK_TYPES,
	FN_NAMES,
	mapRPCResponse,
	parseMessagePackData,
    RunCmdRequest,
    MsgpackError,
    RunCmdResponse,
} from "./rpc";
import { CommandEntry } from "./obsidian-types";

interface Settings {
	socketPath: string;
}

export function mapCommand(includeName: boolean, includeIcons: boolean) {
	return function(command: Record<string, string>) {
		const cmd: CommandEntry = {
			id: command.id,
		};

		if (includeName) {
			cmd.name = command.name;
		}

		if (includeIcons) {
			cmd.icon = command.icon;
		}

		return cmd;
	}

}

const DEFAULT_SETTINGS: Settings = {
	socketPath: "/tmp/obsidian-remote.sock",
}

export default class ObsidianRemote extends Plugin {
	settings: Settings;

	private server?: net.Server;

	handleRunCmdRequest(data: RunCmdRequest, socket: net.Socket): void {
		const result = this.app.commands.executeCommandById(data.params.cmdId);

		let error: MsgpackError = null;

		if (!result) {
			error = ["Command not found"];
		}

		const response: RunCmdResponse = {
			id: data.id,
			type: MSGPACK_TYPES.Response,
			error,
			result,
		};

		const mappedResponse = mapRPCResponse(response);
		const encodedResponse = msgpack.encode(mappedResponse);

		socket.write(encodedResponse, (err) => {
			if (err) {
				console.error(err);
				return;
			}
		});
	}

	handleListCmdsRequest(data: ListCmdsRequest, socket: net.Socket): void {
		const result = this.app.commands.listCommands().map(
			mapCommand(data.params.includeNames, data.params.includeIcons)
		);

		const response: ListCmdsResponse = {
			id: data.id,
			type: MSGPACK_TYPES.Response,
			error: null,
			result,
		};

		const mappedResponse = mapRPCResponse(response);

		console.log("Sending response: ", mappedResponse);

		const encodedResponse = msgpack.encode(mappedResponse);

		socket.write(encodedResponse, (err) => {
			if (err) {
				console.error(err);
				return;
			}
		});
	}

	handleIPCMessage(message: unknown, socket: net.Socket): void {
		const parsedData = parseMessagePackData(message);
		if (parsedData instanceof Error) {
			console.error(parsedData);
			return;
		}

		if (parsedData.type !== MSGPACK_TYPES.Request) {
			console.error("Received non-request message");
			return;
		}

		switch (parsedData.fnName) {
			case FN_NAMES.ListCmds: {
				this.handleListCmdsRequest(parsedData, socket);
				break;
			}
			case FN_NAMES.RunCmd: {
				this.handleRunCmdRequest(parsedData, socket);
				break;
			}
		}
	}

	startIPCServer() {
		const { socketPath } = this.settings;

		this.server = net.createServer({ pauseOnConnect: true }, (socket) => {
			socket.on("readable", async () => {
				for await (const message of msgpack.decodeMultiStream(socket)) {
					this.handleIPCMessage(message, socket);
				}

				socket.end();
			});
		});

		if (fs.existsSync(socketPath)) {
			fs.unlinkSync(socketPath);
		}

		this.server.listen(socketPath, () => {
			console.log("server listening to connections on " + this.settings.socketPath);
		});
	}

	async onload() {
		await this.loadSettings();
		this.startIPCServer();
		this.addSettingTab(new SettingTab(this.app, this));
	}

	onunload() {
		this.server?.close();
	}

	async loadSettings() {
		this.settings = Object.assign({}, DEFAULT_SETTINGS, await this.loadData());
	}

	async saveSettings() {
		await this.saveData(this.settings);
	}
}

class SettingTab extends PluginSettingTab {
	plugin: ObsidianRemote;

	constructor(app: App, plugin: ObsidianRemote) {
		super(app, plugin);
		this.plugin = plugin;
	}

	display(): void {
		const {containerEl} = this;

		containerEl.empty();

		new Setting(containerEl)
			.setName('UNIX Socket path')
			.setDesc('Path to the UNIX socket to bind to')
			.addText(text => text
				.setPlaceholder('/tmp/obsidian-remote.sock')
				.setValue(this.plugin.settings.socketPath)
				.onChange(async (value) => {
					this.plugin.settings.socketPath = value;
					await this.plugin.saveSettings();
				}));
	}
}
