module.exports = {
  apps: [
    {
      name: "shop_bot",
      script: "bash",
      args: "-lc 'cd /root/TH3V151T0R5_S && bundle exec ruby main.rb'",
      interpreter: "none",
      cwd: "/root/TH3V151T0R5_S",
    },
  ],
};
