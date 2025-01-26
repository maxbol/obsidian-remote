declare module "obsidian" {
	interface App {
		commands: Commands;
	}

}

export interface CommandEntry {
	id: string;
	name?: string;
	icon?: string;
}

export interface Commands {
	commands: Record<string, CommandEntry>;
	executeCommandById(id: string): boolean;
	listCommands(): Record<string, string>[];
}

