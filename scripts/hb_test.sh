#!/bin/bash
source ~/miniconda3/etc/profile.d/conda.sh
conda activate hummingbot
cd ~/projects/hummingbot
echo "=== Python ==="
python --version
which python
echo "=== Hummingbot version ==="
python -c 'import hummingbot; print(hummingbot.get_version())'
echo "=== Cython modules ==="
python -c 'from hummingbot.core.pubsub import PubSub; print("pubsub OK")'
python -c 'from hummingbot.strategy.pure_market_making.pure_market_making import PureMarketMakingStrategy; print("pure_market_making OK")'
python -c 'from hummingbot.strategy.avellaneda_market_making.avellaneda_market_making import AvellanedaMarketMakingStrategy; print("avellaneda OK")'
echo "=== Connectors check ==="
python -c 'from hummingbot.connector.derivative.bybit_perpetual.bybit_perpetual_derivative import BybitPerpetualDerivative; print("bybit_perpetual connector loads")'
echo "=== git commit ==="
git -C ~/projects/hummingbot log -1 --format='%h %s (%ad)' --date=short
