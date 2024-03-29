# Copyright (c) 2018 Foundries.io
#
# SPDX-License-Identifier: Apache-2.0

from runners.core import WellsL4BinaryRunner

def test_runner_imports():
    # Ensure that all runner modules are imported and returned by
    # get_runners().
    #
    # This is just a basic sanity check against errors introduced by
    # tree-wide refactorings for runners that don't have their own
    # test suites.
    runner_names = set(r.name() for r in WellsL4BinaryRunner.get_runners())

    # Please keep this sorted alphabetically.
    expected = set(('arc-nsim',
                    'blackmagicprobe',
                    'bossac',
                    'dediprog',
                    'dfu-util',
                    'em-starterkit',
                    'esp32',
                    'hifive1',
                    'intel_s1000',
                    'jlink',
                    'misc-flasher',
                    'nios2',
                    'nrfjprog',
                    'openocd',
                    'pyocd',
                    'qemu',
                    'stm32flash',
                    'xtensa'))
    assert runner_names == expected
