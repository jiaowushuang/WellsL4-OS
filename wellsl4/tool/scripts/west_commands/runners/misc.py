# Copyright (c) 2019, Nordic Semiconductor ASA
#
# SPDX-License-Identifier: Apache-2.0

'''Catch-all module for miscellaneous devices which can't use a
generic or widely used tool like J-Link, OpenOCD, etc.

Please use this sparingly and only when your setup is exotic and
you're willing to handle requests for help. E.g. if your "board" is a
core on a special-purpose SoC which requires a complicated script to
network boot.'''

from runners.core import WellsL4BinaryRunner, RunnerCaps

class MiscFlasher(WellsL4BinaryRunner):
    '''Runner for handling special purpose flashing commands.'''

    def __init__(self, cfg, command, args):
        super().__init__(cfg)
        if not command:
            # This is a board definition error, not a user error,
            # so we can do it now and not in do_run().
            raise ValueError('no command was given')
        self.command = command
        self.args = args

    @classmethod
    def name(cls):
        return 'misc-flasher'

    @classmethod
    def capabilities(cls):
        return RunnerCaps(commands={'flash'})

    @classmethod
    def do_add_parser(cls, parser):
        parser.add_argument('command',
                            help='''command to run; it will be passed the
                            build directory as its first argument''')
        parser.add_argument('args', nargs='*',
                            help='''additional arguments to pass after the build
                            directory''')

    @classmethod
    def create(cls, cfg, args):
        return MiscFlasher(cfg, args.command, args.args)

    def do_run(self, *args, **kwargs):
        self.require(self.command)
        self.check_call([self.command, self.cfg.build_dir] + self.args)
