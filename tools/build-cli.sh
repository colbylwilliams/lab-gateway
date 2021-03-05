#!/bin/bash
set -e

cdir=$(cd -P -- "$(dirname -- "$0")" && pwd -P)
tcdir=${cdir%/*}

echo "DevTestLabs Gateway CLI Build Utility"
echo ""

pushd $tcdir > /dev/null

    echo "Creating a virtual environment"
    python -m venv env
    echo ""

    echo "Activating virtual environment"
    source env/bin/activate
    echo ""

    echo "Installing Azure CLI Dev Tools (azdev)"
    pip install azdev
    echo ""

    echo "Setting up Azure CLI Dev Tools (azdev)"
    azdev setup -r $PWD -e lab-gateway
    echo ""

    echo "Running Linter on DevTestLabs Gateway CLI source"
    azdev linter lab-gateway
    echo ""

    echo "Running Style Checks on DevTestLabs Gateway CLI source"
    azdev style lab-gateway
    echo ""

    echo "Building DevTestLabs Gateway CLI"
    azdev extension build lab-gateway
    echo ""

    echo "Deactivating virtual environment"
    deactivate
    echo ""

popd > /dev/null

echo "Done."
echo ""
