#!/bin/bash
set -e

if [ -z "$DOCKER_COMPOSE_COMMAND" ]
then
    DOCKER_COMPOSE_COMMAND="docker compose"
fi

if [ -z "$1" ]
then
    echo "Usage:"
    echo "./do run [command] - run a command"
    exit 1
fi

if [ "$1" == "build" ] || [ "$1" == "b" ]
then
    echo Running: ${DOCKER_COMPOSE_COMMAND} build
    ${DOCKER_COMPOSE_COMMAND} build
    exit 0
fi

if [ "$1" == "up" ] || [ "$1" == "u" ]
then
    echo Running: ${DOCKER_COMPOSE_COMMAND} up -d --remove-orphans
    ${DOCKER_COMPOSE_COMMAND} up -d --remove-orphans
    exit 0
fi

if [ "$1" == "down" ] || [ "$1" == "d" ]
then
    echo Running: ${DOCKER_COMPOSE_COMMAND} down "${@:2}"
    ${DOCKER_COMPOSE_COMMAND} down "${@:2}"
    exit 0
fi

if [ "$1" == "restart" ] || [ "$1" == "rs" ]
then
    echo Running: ${DOCKER_COMPOSE_COMMAND} restart "${@:2}"
    ${DOCKER_COMPOSE_COMMAND} restart "${@:2}"
    exit 0
fi

if [ "$1" == "run" ] || [ "$1" == "r" ]
then
    echo Running: ${DOCKER_COMPOSE_COMMAND} run --remove-orphans --rm ruby ${@:2}
    ${DOCKER_COMPOSE_COMMAND} run --remove-orphans --rm ruby "${@:2}"
    exit 0
fi

if [ "$1" == "rake" ] || [ "$1" == "rk" ]
then
    echo Running: ${DOCKER_COMPOSE_COMMAND} run --remove-orphans --rm ruby rake ${@:2}
    ${DOCKER_COMPOSE_COMMAND} run --remove-orphans --rm ruby rake "${@:2}"
    exit 0
fi

if [ "$1" == "dummy:start" ] || [ "$1" == "ds" ]
then
    echo Running: ${DOCKER_COMPOSE_COMMAND} run --remove-orphans --rm -p 3000:3000 ruby test/dummy/bin/dev ${@:2}
    ${DOCKER_COMPOSE_COMMAND} run --remove-orphans --rm -p 3000:3000 ruby test/dummy/bin/dev "${@:2}"
    exit 0
fi

if [ "$1" == "dummy:rails" ] || [ "$1" == "dr" ]
then
    echo Running: ${DOCKER_COMPOSE_COMMAND} run --remove-orphans --rm ruby test/dummy/bin/rails ${@:2}
    ${DOCKER_COMPOSE_COMMAND} run --remove-orphans --rm ruby test/dummy/bin/rails "${@:2}"
    exit 0
fi

if [ "$1" == "npm" ]
then
    echo Running: ${DOCKER_COMPOSE_COMMAND} run --remove-orphans --rm node npm ${@:2}
    ${DOCKER_COMPOSE_COMMAND} run --remove-orphans --rm node npm "${@:2}"
    exit 0
fi

if [ "$1" == "npx" ]
then
    echo Running: ${DOCKER_COMPOSE_COMMAND} run --remove-orphans --rm node npm run ${@:2}
    ${DOCKER_COMPOSE_COMMAND} run --remove-orphans --rm node npm run "${@:2}"
    exit 0
fi

if [ "$1" == "cs" ] || [ "$1" == "c" ]
then
    echo Running: ${DOCKER_COMPOSE_COMMAND} run --remove-orphans --rm ruby rubocop "${@:2}"
    ${DOCKER_COMPOSE_COMMAND} run --remove-orphans --rm ruby rubocop "${@:2}"
    exit 0
fi

if [ "$1" == "cs:fix" ]
then
    echo Running: ${DOCKER_COMPOSE_COMMAND} run --remove-orphans --rm ruby rubocop --autocorrect "${@:2}"
    ${DOCKER_COMPOSE_COMMAND} run --remove-orphans --rm ruby rubocop --autocorrect "${@:2}"
    exit 0
fi

if [ "$1" == "test" ] || [ "$1" == "t" ]
then
    echo Running: ${DOCKER_COMPOSE_COMMAND} run --remove-orphans --rm ruby rake test "${@:2}"
    ${DOCKER_COMPOSE_COMMAND} run --remove-orphans --rm ruby rake test "${@:2}"
    exit 0
fi

if [ "$1" == "testall" ] || [ "$1" == "ta" ]
then
    echo "Running test suite against Ruby 3.3"
    docker run --rm \
      -v "$(pwd)":/var/source \
      -w /var/source \
      ruby:3.3 \
      bash -c "bundle install && bundle exec appraisal install && bundle exec appraisal rake test" \
      2>&1 >/dev/null \
      && echo "Tests pass on Ruby 3.3!" || echo "Tests fails for Ruby 3.3 :("
    echo ""

exit 0

    echo "Running test suite against Ruby 3.4"
    docker run --rm \
      -v "$(pwd)":/var/source \
      -w /var/source \
      ruby:3.4 \
      bash -c "bundle install && bundle exec appraisal install && bundle exec appraisal rake test" \
      2>&1 >/dev/null \
      && echo "Tests pass on Ruby 3.4!" || echo "Tests fails for Ruby 3.4 :("
    echo ""

    echo "Running test suite against Ruby 4.0"
    docker run --rm \
      -v "$(pwd)":/var/source \
      -w /var/source \
      ruby:4.0 \
      bash -c "bundle install && bundle exec appraisal install && bundle exec appraisal rake test" \
      2>&1 >/dev/null \
      && echo "Tests pass on Ruby 4.0!" || echo "Tests fails for Ruby 4.0 :("
    echo ""

    exit 0
fi

if [ "$1" == "l" ] || [ "$1" == "log" ] || [ "$1" == "logs" ]
then
    echo Running: ${DOCKER_COMPOSE_COMMAND} logs "${@:2}"
    ${DOCKER_COMPOSE_COMMAND} logs "${@:2}"
    exit 0
fi

if [ "$1" == "ps" ]
then
    echo Running: ${DOCKER_COMPOSE_COMMAND} ps "${@:2}"
    ${DOCKER_COMPOSE_COMMAND} ps "${@:2}"
    exit 0
fi

echo Running: ${DOCKER_COMPOSE_COMMAND} "${@:1}"
${DOCKER_COMPOSE_COMMAND} "${@:1}"
