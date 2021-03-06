#
# logrotate.pl is written
# by "AYANOKOUZI, Ryuunosuke" <i38w7i3@yahoo.co.jp>
# under GNU General Public License v3.
#
# Name
#	logrotate.pl - yet another log rotation for weechatlog
#
# Description
#	logrotate is designed for rotation logfiles by using pure
#	WeeChat environment. it allows to automatic rotate weechatlogs
#	for any buffer with DIFFERRNT configuration.
#
#	Prior to the consideration of using logrotate.pl, check
#	"WeeChat User's Guide Section 4.7. Logger plugin"
#	first. WeeChat provide us quasi-logrotate manner officially
#	[1]. for example,
#
#	/set logger.mask.irc.freenode.#weechat "$server.$channel/%Y-%m-%d-%H:%M:%S"
#
#	Note that it's change the path of log file not every one
#	second but every one day even %S specifier used.
#
#	[1] http://www.weechat.org/files/doc/stable/weechat_user.en.html#logger_files_by_date
#
# Usage
# /set plugins.var.perl.logrotate.server.#channel.timer 600
#	Set log rotation timer 600 for the buffer named
#	server.#channel. weechatlog file will be rotated for every 600
#	seconds.
#
# /set plugins.var.perl.logrotate.server.#channel.format /home/hoge/.weechat/logs/server.#channel/%Y-%m-%d-%H:%M:%S
#	Set logfile format for the buffer named server.#channel.
#	weechatlog file will be renamed according to the format.
#	Special calacters(%Y, %m, %d ...) defined in the Perl module
#	Time::Piece are allowed to use, for the detail information of
#	them, check the URLs[2,3] below.
#
#	[2] http://www.unix.com/man-page/FreeBSD/3/strftime/
#	[3] http://search.cpan.org/~msergeant/Time-Piece/Piece.pm
#
# /unset plugins.var.perl.logrotate.server.#channel.timer
# /unset plugins.var.perl.logrotate.server.#channel.format
# /set plugins.var.perl.logrotate.server.#channel.timer 0
# /set plugins.var.perl.logrotate.server.#channel.format null
#	Remove a configuration. to make logrotate disable, you can
#	remove either timer or format parameter.
#

use strict;
use warnings;
use Time::Piece;
use Data::Dumper;
use File::Basename;
use File::Path;

weechat::register("logrotate", "AYANOKOUZI, Ryuunosuke", "0.1.0", "GPL3", "logrotate", "", "");
weechat::hook_config("plugins.var.perl.logrotate.*", "config_cb", "");

my $conf = &config();

sub option_get
{
	my $prefix = shift;

	my $conf;
	my $il = weechat::infolist_get('option', '', "$prefix.*");
	while (weechat::infolist_next($il)) {
		my $full_name = weechat::infolist_string($il, 'full_name');
		if ($full_name =~ m/$prefix\.(.*)\.([^.]*)\Z/) {
			$conf->{$1}->{$2} = weechat::infolist_string($il, 'value');
		}
	}
	weechat::infolist_free($il);

	return $conf;
}

sub config
{
	my $conf = &option_get("plugins.var.perl.logrotate");
	weechat::print("", Dumper $conf);
	while (my ($key, $val) = each %{$conf}) {
		next if ! defined $val->{format} || $val->{format} eq '';
		next if ! defined $val->{timer} || $val->{timer} == 0;
		$val->{hook} = weechat::hook_timer(1000 * $val->{timer}, $val->{timer}, 0, "my_signal_day_changed", $key);
	}

	weechat::print("", Dumper $conf);
	return $conf;
}

sub config_cb
{
	my $data = shift;
	my $option = shift;
	my $value = shift;
	while (my ($key, $val) = each %{$conf}) {
		next if ! defined $val->{hook} || $val->{hook} eq '';
		weechat::unhook($val->{hook});
	}
	$conf = &config();
	return weechat::WEECHAT_RC_OK;
}

sub my_signal_day_changed
{
#	weechat::print("", "");
	my $data = shift;
#	weechat::print("", $data);
	return weechat::WEECHAT_RC_OK if !defined $conf->{$data};

	my $il = weechat::infolist_get('buffer', '', "*$data*");
	while (weechat::infolist_next($il)) {
		my $name = weechat::infolist_string($il, 'name');
		next if lc $name ne lc $data;
#		weechat::print("", $name);
		my $pointer = weechat::infolist_pointer($il, 'pointer');
		my $il1 = weechat::infolist_get('logger_buffer', '', '');
		while (weechat::infolist_next($il1)) {
			my $buffer = weechat::infolist_pointer($il1, 'buffer');
			next if $buffer ne $pointer;
#			weechat::print("", $buffer);
			my $log_filename = weechat::infolist_string($il1, 'log_filename');
			next if $log_filename eq '';
#			weechat::print("", $log_filename);
			my $log_enabled = weechat::infolist_integer($il1, 'log_enabled');
			next if $log_enabled != 1;
#			weechat::print("", $log_enabled);
			my $log_level = weechat::infolist_integer($il1, 'log_level');
			next if $log_level == 0;
#			weechat::print("", $log_level);
			my $t = localtime;
			my $log_filename_new = $t->strftime($conf->{$data}->{format});
			eval { mkpath(dirname($log_filename_new)); };
			weechat::print("", "ERROR:mkpath, $@") && next if $@;
#			weechat::print("", $log_filename_new);
			rename $log_filename, $log_filename_new;
			weechat::print("", "$log_filename => $log_filename_new");
			weechat::command($buffer, "/mute logger disable");
			weechat::command($buffer, "/mute logger set $log_level");
		}
		weechat::infolist_free($il1);
	}
	weechat::infolist_free($il);

	return weechat::WEECHAT_RC_OK;
}
