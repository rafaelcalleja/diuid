ENV ?= token
INPUT_TYPE ?= dotenv
OUTPUT_TYPE ?= dotenv

KEY_COMMENT ?= new key
KEY_NAME ?= diud
PUB_KEY := $(shell gpg --fingerprint $(KEY_NAME) | grep pub -A 1 | grep -v pub | sed s/\ //g)
PRIVATE_KEY := $(shell gpg --export-secret-keys --armor $(KEY_NAME)|base64 |  tr -d '\n')

.PHONY: list_keys
list_keys:
	gpg --list-secret-keys $(KEY_NAME)

.PHONY: pub_key
pub_key:
	@echo $(PUB_KEY)

.PHONY: priv_key
priv_key:
	@echo $(PRIVATE_KEY)

.PHONY: create_keys
create_keys:
	gpg --batch --full-generate-key <<EOF \
%no-protection \
Key-Type: 1 \
Key-Length: 4096 \
Subkey-Type: 1 \
Subkey-Length: 4096 \
Expire-Date: 0 \
Name-Comment: $(KEY_COMMENT) \
Name-Real: $(KEY_NAME) \
EOF

.PHONY: encrypt
encrypt:
ifndef TEXT
	$(error TEXT is required, make encrypt TEXT=text to encrypt")
endif
	@echo "Encrypted $(TEXT) into file $(ENV).$(INPUT_TYPE)"
	@echo $(TEXT) |sops --encrypt --pgp $(PUB_KEY) --input-type $(INPUT_TYPE) --output-type $(OUTPUT_TYPE) /dev/stdin > $(ENV).$(INPUT_TYPE)

.PHONY: encoded
encoded:
	@cat $(ENV).$(INPUT_TYPE) |base64 -w0

.PHONY: decrypt
decrypt:
	@sops --decrypt --input-type $(OUTPUT_TYPE) --output-type $(OUTPUT_TYPE) $(ENV).$(INPUT_TYPE)
