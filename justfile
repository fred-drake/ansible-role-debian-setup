default: lint test
lint:
    hadolint Dockerfile
    yamllint .
    ANSIBLE_ROLES_PATH=./ ansible-lint .

test:
    molecule test
