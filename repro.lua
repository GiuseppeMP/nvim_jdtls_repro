-- run with nvim -u repro.lua
-- DO NOT change the paths
local root = vim.fn.fnamemodify("./.repro", ":p")
local home = os.getenv "HOME"

-- set stdpaths to use .repro
for _, name in ipairs({ "config", "data", "state", "runtime", "cache" }) do
    vim.env[("XDG_%s_HOME"):format(name:upper())] = root .. "/" .. name
end

-- bootstrap lazy
local lazypath = root .. "/plugins/lazy.nvim"
if not vim.loop.fs_stat(lazypath) then
    vim.fn.system({
        "git",
        "clone",
        "--filter=blob:none",
        "--single-branch",
        "https://github.com/folke/lazy.nvim.git",
        lazypath,
    })
end
vim.opt.runtimepath:prepend(lazypath)

-- install plugins
local plugins = {
    "folke/tokyonight.nvim",
    {
        "ibhagwan/fzf-lua",
        config = function()
            require('fzf-lua').setup({
                keymap = {
                    builtin = {
                        -- for builtin previewer
                        ["<C-d>"] = "preview-page-down",
                        ["<C-u>"] = "preview-page-up",
                    },
                    fzf = {
                        -- for fzf application
                        ["enter"] = "accept",
                        ["ctrl-a"] = "toggle-all",
                        ["tab"] = "toggle+down",
                        ["shift-tab"] = "toggle+up",
                        -- for external fzf previewers
                        -- ["<C-u>"] = "preview-page-up",
                        -- ["<C-d>"] = "preview-page-down",
                    },
                },
                files = {
                    show_cwd_header = true
                },
                buffers = {
                    show_cwd_header = true,
                    ignore_current_buffer = true,
                },
                git = {
                    show_cwd_header = true,
                },
                lsp = {
                    symbols = {
                        symbol_style = 1,
                        -- filter symbol types like class
                        -- function, interface, struct etc
                        regex_filter = "%[([SCMFDI].*)%].*",
                    },
                },
            })
            vim.keymap.set("n", "<c-P>", "<cmd>lua require('fzf-lua').files()<CR>", { silent = true })
        end
    },
    {
        'williamboman/mason.nvim',
        dependencies = { 'WhoIsSethDaniel/mason-tool-installer.nvim' },
        config = function()
            require('mason').setup({
                ui = {
                    icons = {
                        package_installed = "✓",
                        package_pending = "➜",
                        package_uninstalled = "✗"
                    }
                }
            })
        end,
    },
    { 'williamboman/mason-lspconfig.nvim', },
    {
        'WhoIsSethDaniel/mason-tool-installer.nvim',
        config = function()
            require("mason-tool-installer").setup({

                ensure_installed = {
                    { 'jdtls', auto_update = true },
                },
                auto_update = true,
                run_on_start = true,
                start_delay = 1000, -- 3 second delay
            })
        end
    },
    { 'neovim/nvim-lspconfig', },
    {
        'mfussenegger/nvim-jdtls',
        config = function()
            local function get_os_string()
                local os
                if vim.fn.has "macunix" then
                    os = "mac"
                elseif vim.fn.has "win32" then
                    os = "win"
                else
                    os = "linux"
                end
                return os
            end
            local project_name = vim.fn.fnamemodify(vim.fn.getcwd(), ":p:h:t")

            local workspace_folder = function() return vim.fn.stdpath "data" .. "/jdtls/workspace_root/" .. project_name end

            local mason_registry = require("mason-registry");

            local get_package_install_path = function(package_name)
                return mason_registry.get_package(package_name):get_install_path()
            end

            local function get_cmd()
                local jdtls_path = get_package_install_path('jdtls')
                local java_home = os.getenv "JAVA_HOME"
                return {
                    java_home .. '/bin/java', -- jdk used for LSP Server
                    '-Declipse.application=org.eclipse.jdt.ls.core.id1',
                    '-Dosgi.bundles.defaultStartLevel=4',
                    '-Declipse.product=org.eclipse.jdt.ls.core.product',
                    '-Dlog.protocol=true',
                    '-Dlog.level=ALL',
                    '-Xms256m',
                    '--add-modules=ALL-SYSTEM',
                    '--add-opens',
                    'java.base/java.util=ALL-UNNAMED',
                    '--add-opens',
                    'java.base/java.lang=ALL-UNNAMED',
                    '-jar', vim.fn.glob(jdtls_path .. "/plugins/org.eclipse.equinox.launcher_*.jar"),
                    '-configuration', jdtls_path .. "/config_" .. get_os_string(),
                    '-data', workspace_folder(),
                }
            end

            local jdtls = require("jdtls")
            local root_markers = { 'pom.xml', 'gradlew', 'mvnw', '.git', 'settings.gradle', '.lsp_root' }
            local root_dir = function() return require('jdtls.setup').find_root(root_markers) end


            local function jdtls_start_or_attach()
                local config = {
                    cmd = get_cmd(),
                    root_dir = root_dir(),
                }
                jdtls.start_or_attach(config)
            end

            vim.api.nvim_create_autocmd("Filetype", {
                pattern = "java", -- autocmd to start jdtls in java files
                callback = jdtls_start_or_attach
            })
        end
    },
}

require("lazy").setup(plugins, {
    root = root .. "/plugins",
})


vim.cmd.colorscheme("tokyonight")
