import re

newline = re.compile('\r\n|\r|\n')

def readme():
    with open('README.rst', 'r') as f:
        return '\n'.join([newline.sub('', ln) for ln in f])
def classifiers():
    with open('classifiers', 'r') as f:
        return [newline.sub('', ln) for ln in f]
def version():
    with open('yawinpty.pyx', 'r') as f:
        for ln in f:
            if ln.startswith('__version__ ='):
                return newline.sub('', ln[15:])[:-1]
def static(compiler):
    compiler.initialize()
    try:
        compiler.compile_options[compiler.compile_options.index('/MD')] = '/MT'
    except ValueError:
        pass
