package system.log

# Avoid logging API keys
mask["/input/attributes/request/http/headers/authorization"]
mask["/result/headers/authorization"]

# In production we might wish to avoid logging IP addresses
# mask["/input/attributes/request/http/headers/x-forwarded-for"]
# mask["/input/attributes/source"]
