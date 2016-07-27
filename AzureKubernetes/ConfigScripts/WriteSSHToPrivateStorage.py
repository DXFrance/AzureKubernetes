#!/usr/bin/python

import sys,os
from azure.storage.blob import BlockBlobService
from azure.storage.blob import ContentSettings


block_blob_service = BlockBlobService(account_name=str(sys.argv[1]), account_key=str(sys.argv[2]))
block_blob_service.create_container('keys')

block_blob_service.create_blob_from_path(
    'keys',
    str(sys.argv[3]),
    os.path.join(os.getcwd(),str(sys.argv[3])),
    content_settings=ContentSettings(content_type='text')
)