#! /usr/bin/env python3
# Copyright Amazon.com, Inc. or its affiliates. All Rights Reserved.
#
# Permission is hereby granted, free of charge, to any person obtaining a copy of
# this software and associated documentation files (the "Software"), to deal in
# the Software without restriction, including without limitation the rights to
# use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies of
# the Software, and to permit persons to whom the Software is furnished to do so.
#
# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
# IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS
# FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR
# COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER
# IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN
# CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.


import argparse
import os
import boto3
import subprocess
import logging
from datetime import datetime
import multiprocessing
from multiprocessing import Value
import logging.handlers
from subprocess import run
timeStamp=datetime.now().isoformat()
LOG_FILENAME="/tmp/FSx-Cache-Eviction-log-"+str(timeStamp)+".txt"
s3 = boto3.client('s3')

def parseArguments():
        parser = argparse.ArgumentParser(description='Cache Eviction script to release least recently accessed files when FSx for Lustre file system free capacity Alarm is triggered')
        parser.add_argument_group('Required arguments')
        parser.add_argument(
                                '-mountpath', required=True, help='Please specify the FSx for Lustre file system mount path')
        parser.add_argument(
                                '-minage', required=True,
                                help='Please specify number of days since last access. Files not accessed for more than this number of days will be considered for hsm release')
        parser.add_argument(
                                '-minsize', required=True,
                                help='Please specify minimum size of file to find')
        parser.add_argument(
                                '-bucket', required=True,
                                help='Please specify the bucket name of the FSx for Lustre data repository')
        parser.add_argument(
                                '-mountpoint', required=True,
                                help='Please specify the mount point used to mount the FSx for Lustre file system')
        args = parser.parse_args()
        return(args)

def getFileList(fileQueue,scannedfiles,mountPath,queue,maxFileQueueProcesses):
    #rank = multiprocessing.current_process()._identity[0]
    #print("In function getFileList: I am on processor:", rank)
    print('Starting getFileList process => {}'.format(os.getpid()))
    worker_configurer(queue)
    logger=logging.getLogger('getFileList')
    try:
        logger.info("Starting scan for directory path %s",mountPath)
        for root,directories,files in os.walk(mountPath,topdown=False):
            for name in files:
                fileQueue.put(os.path.join(root, name))
        scannedfiles.value=fileQueue.qsize()
    except Exception as e:
        logger.error("Caught Exception. Error is: %s", e)
    for i in range(maxFileQueueProcesses):
        fileQueue.put(None)

def checkFileAge(fileQueue,hsmQueue,filesMinSize,filesMinAge,queue,eligiblefiles,maxHsmQueueProcesses):
    #rank = multiprocessing.current_process()._identity[0]
    #print("In function checkFileAge: I am on processor:", rank)
    print('Starting checkFileAge process => {}'.format(os.getpid()))
    worker_configurer(queue)
    logger=logging.getLogger('checkFileAge')
    today=datetime.today()
    while True:
        try:
            file=fileQueue.get()
            if file is None:
                break
            atime=os.stat(file).st_atime
            fileage=datetime.fromtimestamp(atime)-today
            #print("FileAge is:", fileage)
            #owner=os.stat(file).st_uid
            #print("File owner is: ", owner)
            fileSize=int(os.stat(file).st_size)
            symlink=os.path.islink(file)
            #print("File name: ",file ,symlink)
            if int(fileage.days) <= -abs(int(filesMinAge)) and fileSize  > int(filesMinSize) and symlink == False:
                hsmQueue.put(file)
                eligiblefiles.value+=1
                logger.info("Adding file to HSM State Queue; with access time more than %s days and file size %s and file is symlink %s: %s", fileage.days, fileSize, symlink, file)
            else:
                logger.info("NOT adding file to HSM State Queue; with access time more than %s days and file size %s and file is symlink %s: %s", fileage.days, fileSize, symlink, file)
        except Exception as e:
            logger.error("Caught Exception. Error is: %s", e)
    hsmQueue.put(None)
    print("file queue is empty")

def getHsmState(hsmQueue,headObjectQueue,queue,validhsmfiles):
    #rank = multiprocessing.current_process()._identity[0]
    #print("In function getHsmState I am on processor:", rank)
    print('Starting getHSMState process  => {}'.format(os.getpid()))
    worker_configurer(queue)
    logger=logging.getLogger('getHsmState')
    while True:
        try:
            file=hsmQueue.get()
            if file is None:
                break
            cmd = "sudo lfs hsm_state "+f'"{file}"'
            p = subprocess.Popen(cmd, stdout=subprocess.PIPE, stderr=subprocess.PIPE, shell=True, universal_newlines=True)
            (output,error)=p.communicate()
            if error !="":
                logger.error("Failed to execute hsm_state on file: %s, error code is: %s",file, error)
            else:
                #print("hsm state of file is:", output)
                if "exists archived"  in output and "released" not in output and "dirty" not in output:
                    validhsmfiles.value+=1
                    headObjectQueue.put(file)
                    logger.info("Adding file to Head Object Queue; with valid hsm_state: %s", file)
                else:
                    logger.info("NOT adding file to Head Object Queue; with invalid hsm_state: %s", file)
        except Exception as e:
            logger.error("Caught Exception. Error is: %s", e)
    headObjectQueue.put(None)
    print("hsm queue is empty")

def headObject(headObjectQueue,releaseQueue,queue,bucket,mountPoint,objectsfound):
    #rank = multiprocessing.current_process()._identity[0]
    #print("In function getObject I am on processor:", rank)
    print('Starting headObject process  => {}'.format(os.getpid()))
    worker_configurer(queue)
    logger=logging.getLogger('headObject')
    while True:
        try:
            file=headObjectQueue.get()
            if file is None:
                 break
            prefix=(os.path.relpath(file, mountPoint))
            response = s3.head_object(
                Bucket=bucket,
                Key=prefix
            )
            http_status_code = response['ResponseMetadata']['HTTPStatusCode']
            if http_status_code == 200:
                releaseQueue.put(file)
                logger.info("Adding file to Releases Queue; file/object returned HTTPStatusCode %s from S3: %s", http_status_code, file)
                objectsfound.value+=1
            else:
                logger.info("NOT adding file to Releaes Queue; file/object returned HTTPStatusCode %s from S3: %s", http_status_code, file)
        except Exception as e:
            logger.error("Caught Exception. Error is: %s for file: %s", e,file)
    releaseQueue.put(None)
    print("head object queue is empty")

def releaseFiles(releaseQueue,queue,releasedfiles):
    #rank = multiprocessing.current_process()._identity[0]
    #print("In function releaseFiles I am on processor:", rank)
    print('Starting releaseFiles thread  => {}'.format(os.getpid()))
    worker_configurer(queue)
    logger=logging.getLogger('releaseFiles')
    while True:
        try:
            file=releaseQueue.get()
            if file is None:
                 break
            cmd = "sudo lfs hsm_release "+f'"{file}"'
            p = subprocess.Popen(cmd, stdout=subprocess.PIPE, stderr=subprocess.PIPE, shell=True, universal_newlines=True)
            (output,error)=p.communicate()
            if error !="":
                logger.error("Failed to execute hsm_release on file: %s, error code is: %s",file, error)
            else:
                logger.info("Initiated HSM release on file: %s",file)
                releasedfiles.value+=1
        except Exception as e:
            logger.error("Caught Exception. Error is: %s", e)
    print("release queue is empty")

def listener_process(queue):
    listener_configurer()
    while True:
        record=queue.get()
        if record is None:
            break
        logger=logging.getLogger(record.name)
        logger.handle(record)

def listener_configurer():
    root = logging.getLogger()
    file_handler = logging.handlers.RotatingFileHandler(LOG_FILENAME, 'a', 102400000, 100)
    formatter = logging.Formatter('%(asctime)s %(processName)-10s %(name)s %(levelname)-8s %(message)s')
    file_handler.setFormatter(formatter)
    root.addHandler(file_handler)
    root.setLevel(logging.INFO)

def worker_configurer(queue):
    h = logging.handlers.QueueHandler(queue)
    root = logging.getLogger()
    root.addHandler(h)
    root.setLevel(logging.INFO)

def  mainLog(queue,scannedfiles,filesMinSize,filesMinAge,eligiblefiles,validhsmfiles,objectsfound,releasedfiles):
        worker_configurer(queue)
        logger=logging.getLogger('Main Process')
        logger.info("Total files scanned: %s", scannedfiles.value)
        logger.info("Total files not accessed for %s days and size larger than %s: %s", filesMinAge, filesMinSize, eligiblefiles.value)
        logger.info("Total files in exists archived HSM state: %s", validhsmfiles.value)
        logger.info("Total files found in S3: %s", objectsfound.value)
        logger.info("Total files released: %s", releasedfiles.value)
        return()

##############################################################################
# Main function
##############################################################################
def main():
        scannedfiles=Value('i',0)
        eligiblefiles=Value('i',0)
        validhsmfiles=Value('i',0)
        objectsfound=Value('i',0)
        releasedfiles=Value('i',0)
        global region
        args = parseArguments()
        mountPath=args.mountpath
        filesMinSize=args.minsize
        filesMinAge=args.minage
        bucket=args.bucket
        mountPoint=args.mountpoint
        queue=multiprocessing.Queue(-1)
        listener=multiprocessing.Process(target=listener_process, args=(queue,))
        listener.start()

        cpuCount=multiprocessing.cpu_count()
        maxFileQueueProcesses=int(((cpuCount/2)-2)/2)
        maxHsmQueueProcesses=int(((cpuCount/2)-2)/2)
        maxHeadObjectQueueProcesses=int(((cpuCount/2)-2)/2)
        maxReleaseProcesses=int(((cpuCount/2)-2)/2)

        #cpuCount=1
        #maxFileQueueProcesses=1
        #maxHsmQueueProcesses=1
        #maxHeadObjectQueueProcesses=1
        #maxReleaseProcesses=1

        # Build queues. fileQueue to add files from directory search, hsmQueue to add files not accessed in filesMinAge days, releaseQueue to add files that are in exists archived state and eligible for hsm release.
        manager=multiprocessing.Manager()
        fileQueue=multiprocessing.Queue()
        hsmQueue=multiprocessing.Queue()
        headObjectQueue=multiprocessing.Queue()
        releaseQueue=multiprocessing.Queue()

        # Start Process to scan the input mount or directory path
        fileListProcess=multiprocessing.Process(target=getFileList,args=(fileQueue,scannedfiles,mountPath,queue,maxFileQueueProcesses))
        fileListProcess.start()

        # Start Process to work on files in fileQueue and validate atime and size.
        fileAgeProcess=[multiprocessing.Process(target=checkFileAge,args=(fileQueue,hsmQueue,filesMinSize,filesMinAge,queue,eligiblefiles,maxHsmQueueProcesses)) for i in range(maxFileQueueProcesses)]
        for f in fileAgeProcess:
            f.start()

        # Start Process to fetch files from hsmQueue, validate hsm_state and add to releaseQueue
        getHsmStateProcess=[multiprocessing.Process(target=getHsmState,args=(hsmQueue,headObjectQueue,queue,validhsmfiles)) for i in range(maxHsmQueueProcesses)]
        for h in getHsmStateProcess:
            h.start()

        # Start Process to fetch files from getObjectQueue, validate object header and add to releaseQueue
        headObjectProcess=[multiprocessing.Process(target=headObject,args=(headObjectQueue,releaseQueue,queue,bucket,mountPoint,objectsfound)) for i in range(maxHeadObjectQueueProcesses)]
        for o in headObjectProcess:
            o.start()

        # Start Process to initiate hsm_release for files in releaseQueue
        releaseHsmStateProcess=[multiprocessing.Process(target=releaseFiles,args=(releaseQueue,queue,releasedfiles)) for i in range(maxReleaseProcesses)]
        for p in releaseHsmStateProcess:
            p.start()

        fileListProcess.join()
        fileQueue.close()

        for f in fileAgeProcess:
            f.join()
        hsmQueue.close()

        for h in getHsmStateProcess:
            h.join()
        headObjectQueue.close()

        for o in headObjectProcess:
            o.join()
        releaseQueue.close()

        for p in releaseHsmStateProcess:
            p.join()

        mainLog(queue,scannedfiles,filesMinSize,filesMinAge,eligiblefiles,validhsmfiles,objectsfound,releasedfiles)
        queue.put(None)
        listener.join()


##############################################################################
# Run from command line
##############################################################################
if __name__ == '__main__':
        main()