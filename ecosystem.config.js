module.exports = {
  apps: [
    {
      name: "shop_bot",
      script: "main.rb",
      interpreter: "bash",
      interpreter_args: "-lc 'bundle exec ruby main.rb'",
      cwd: "/root/mastodon_bots/shop_bot",
      env: {
        GEM_PATH: "/var/lib/gems/3.2.0",
        RUBYLIB: "/var/lib/gems/3.2.0/lib/ruby/gems/3.2.0",
      },
    },
  ],
};
