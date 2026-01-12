# marcha.config.json Standard

This document describes the schema for `marcha.config.json` files used to define project-specific scripts in Marcha.

## Overview

A `marcha.config.json` file allows you to define scripts that can be executed from within Marcha. These scripts can have configurable inputs that are prompted to the user before execution.

## Schema

### Root Object

| Field | Type | Required | Description |
|-------|------|----------|-------------|
| `version` | string | Yes | Schema version (currently `"1.0"`) |
| `project` | object | No | Project metadata |
| `scripts` | array | Yes | Array of script definitions |

### Project Object

| Field | Type | Required | Description |
|-------|------|----------|-------------|
| `name` | string | No | Project display name |
| `description` | string | No | Project description |

### Script Object

| Field | Type | Required | Description |
|-------|------|----------|-------------|
| `id` | string | Yes | Unique identifier for the script |
| `name` | string | Yes | Display name shown in the UI |
| `executable` | string | Yes | Command or executable to run |
| `arguments` | array | No | Array of argument strings (supports `${inputId}` substitution) |
| `workingDirectory` | string | No | Working directory (defaults to config file location) |
| `emoji` | string | No | Emoji icon for the script |
| `description` | string | No | Description shown in the UI |
| `inputs` | array | No | Array of input definitions |

### Input Object

| Field | Type | Required | Description |
|-------|------|----------|-------------|
| `id` | string | Yes | Unique identifier for the input (used in argument substitution) |
| `name` | string | Yes | Display label for the input |
| `type` | string | Yes | Input type (see Input Types below) |
| `default` | any | No | Default value |
| `description` | string | No | Help text shown below the input |
| `options` | array | No | Required for `select` type |

### Input Types

| Type | Description | Value Format |
|------|-------------|--------------|
| `string` | Text input | String value |
| `number` | Numeric input | Number value |
| `boolean` | Checkbox toggle | `true` or `false` |
| `file` | File picker | Absolute file path |
| `directory` | Directory picker | Absolute directory path |
| `select` | Dropdown selection | Selected option value |

### Select Options

For `select` type inputs, each option should have:

| Field | Type | Required | Description |
|-------|------|----------|-------------|
| `value` | string | Yes | The value passed to the command |
| `label` | string | Yes | Display text shown in the dropdown |

## Argument Substitution

Use `${inputId}` syntax in arguments to substitute input values:

```json
{
  "arguments": ["--mode", "${buildMode}", "--output", "${outputDir}"]
}
```

## Example

```json
{
  "version": "1.0",
  "project": {
    "name": "My Web App",
    "description": "Frontend development scripts"
  },
  "scripts": [
    {
      "id": "dev",
      "name": "Start Dev Server",
      "executable": "npm",
      "arguments": ["run", "dev"],
      "emoji": "🚀",
      "description": "Start the development server with hot reload"
    },
    {
      "id": "build",
      "name": "Build for Production",
      "executable": "npm",
      "arguments": ["run", "build", "--", "--mode", "${mode}"],
      "emoji": "📦",
      "inputs": [
        {
          "id": "mode",
          "name": "Build Mode",
          "type": "select",
          "options": [
            { "value": "production", "label": "Production" },
            { "value": "staging", "label": "Staging" }
          ],
          "default": "production"
        }
      ]
    },
    {
      "id": "test",
      "name": "Run Tests",
      "executable": "npm",
      "arguments": ["test", "--", "--coverage", "${coverage}"],
      "emoji": "🧪",
      "inputs": [
        {
          "id": "coverage",
          "name": "Generate Coverage",
          "type": "boolean",
          "default": false
        }
      ]
    },
    {
      "id": "deploy",
      "name": "Deploy to Server",
      "executable": "scp",
      "arguments": ["-r", "./dist", "${server}:${remotePath}"],
      "emoji": "🌐",
      "inputs": [
        {
          "id": "server",
          "name": "Server Address",
          "type": "string",
          "default": "user@example.com"
        },
        {
          "id": "remotePath",
          "name": "Remote Path",
          "type": "string",
          "default": "/var/www/html"
        }
      ]
    }
  ]
}
```

## Usage in Marcha

1. Create a `marcha.config.json` file in your project root
2. In Marcha, click "Add marcha.config.json" in the Scripts section
3. Select your config file
4. Scripts will appear in the Scripts section
5. Click a script to run it (inputs will be prompted if defined)

## Notes

- The working directory defaults to the directory containing the config file
- All paths in file/directory inputs are absolute paths
- Boolean inputs are converted to string `"true"` or `"false"` for argument substitution
- Scripts without inputs run immediately when clicked
